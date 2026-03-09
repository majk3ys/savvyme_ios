import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData

struct UserProfileData: Codable {
    var age: String
    var state: String
    var postcode: String
    var maritalStatus: String
    var adultsCount: String
    var childrenCount: String
    var incomeRange: String
    var housingStatus: String
    var mortgageBalanceGroup: String
    var updatedAt: Date
    
    static func fromDefaults() -> UserProfileData {
        let defaults = UserDefaults.standard
        return UserProfileData(
            age: defaults.string(forKey: "user_age") ?? "",
            state: defaults.string(forKey: "user_state") ?? "Any",
            postcode: defaults.string(forKey: "user_postcode") ?? "",
            maritalStatus: defaults.string(forKey: "user_marital_status") ?? "",
            adultsCount: defaults.string(forKey: "user_adults_count") ?? "",
            childrenCount: defaults.string(forKey: "user_children_count") ?? "",
            incomeRange: defaults.string(forKey: "user_income_range") ?? "Any",
            housingStatus: defaults.string(forKey: "user_housing_status") ?? "renter",
            mortgageBalanceGroup: defaults.string(forKey: "user_mortgage_balance_group") ?? "Any",
            updatedAt: Date(timeIntervalSince1970: defaults.double(forKey: "profile_last_updated"))
        )
    }
    
    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(age, forKey: "user_age")
        defaults.set(state, forKey: "user_state")
        defaults.set(postcode, forKey: "user_postcode")
        defaults.set(maritalStatus, forKey: "user_marital_status")
        defaults.set(adultsCount, forKey: "user_adults_count")
        defaults.set(childrenCount, forKey: "user_children_count")
        defaults.set(incomeRange, forKey: "user_income_range")
        defaults.set(housingStatus, forKey: "user_housing_status")
        defaults.set(mortgageBalanceGroup, forKey: "user_mortgage_balance_group")
        defaults.set(updatedAt.timeIntervalSince1970, forKey: "profile_last_updated")
    }
    
    static func clearDefaults() {
        let defaults = UserDefaults.standard
        ["user_age",
         "user_state",
         "user_postcode",
         "user_marital_status",
         "user_adults_count",
         "user_children_count",
         "user_income_range",
         "user_housing_status",
         "user_mortgage_balance_group",
         "profile_last_updated"].forEach { defaults.removeObject(forKey: $0) }
    }
}

struct RemoteTransaction: Codable {
    var id: UUID
    var name: String
    var amount: Double
    var frequency: String
    var type: String
    var date: Date?
    var budget: Double?
}

enum UserDataError: Error {
    case notAuthenticated
}

final class UserDataService {
    static let shared = UserDataService()
    private let db = Firestore.firestore()
    private init() {}
    
    // MARK: - Helpers
    private func userDocument() throws -> DocumentReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserDataError.notAuthenticated
        }
        return db.collection("users").document(uid)
    }
    
    /// Ensures the user document exists before writing to subcollections.
    private func ensureUserDocumentExists() async throws -> DocumentReference {
        let doc = try userDocument()
        let snapshot = try await doc.getDocument()
        if !snapshot.exists {
            try await doc.setData(["createdAt": Timestamp(date: Date())], merge: true)
        }
        return doc
    }
    
    // MARK: - Profile
    func saveProfile(_ profile: UserProfileData) async throws {
        let doc = try userDocument()
        let payload: [String: Any] = [
            "age": profile.age,
            "state": profile.state,
            "postcode": profile.postcode,
            "maritalStatus": profile.maritalStatus,
            "adultsCount": profile.adultsCount,
            "childrenCount": profile.childrenCount,
            "incomeRange": profile.incomeRange,
            "housingStatus": profile.housingStatus,
            "mortgageBalanceGroup": profile.mortgageBalanceGroup,
            "updatedAt": Timestamp(date: profile.updatedAt)
        ]
        try await doc.setData(payload, merge: true)
    }
    
    func saveBlankProfileIfNeeded() async {
        do {
            let doc = try userDocument()
            let snapshot = try await doc.getDocument()
            if snapshot.exists, snapshot.data()?["age"] != nil {
                return // Profile already saved
            }
            let blank = UserProfileData(
                age: "",
                state: "Any",
                postcode: "",
                maritalStatus: "",
                adultsCount: "",
                childrenCount: "",
                incomeRange: "Any",
                housingStatus: "renter",
                mortgageBalanceGroup: "Any",
                updatedAt: Date()
            )
            try await saveProfile(blank)
            blank.saveToDefaults()
        } catch {
            print("Failed to save blank profile: \(error)")
        }
    }
    
    func fetchProfile() async throws -> UserProfileData? {
        let doc = try userDocument()
        let snapshot = try await doc.getDocument()
        guard let data = snapshot.data() else { return nil }
        
        return UserProfileData(
            age: data["age"] as? String ?? "",
            state: data["state"] as? String ?? "Any",
            postcode: data["postcode"] as? String ?? "",
            maritalStatus: data["maritalStatus"] as? String ?? "",
            adultsCount: data["adultsCount"] as? String ?? "",
            childrenCount: data["childrenCount"] as? String ?? "",
            incomeRange: data["incomeRange"] as? String ?? "Any",
            housingStatus: data["housingStatus"] as? String ?? "renter",
            mortgageBalanceGroup: data["mortgageBalanceGroup"] as? String ?? "Any",
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    // MARK: - Transactions
    func saveTransaction(_ transaction: TransactionItem) async throws {
        let doc = try await ensureUserDocumentExists()
        var payload: [String: Any] = [
            "name": transaction.name,
            "amount": transaction.amount,
            "frequency": transaction.frequency,
            "type": transaction.type,
            "date": Timestamp(date: transaction.date ?? Date())
        ]
        if let budget = transaction.budget {
            payload["budget"] = budget
        }
        try await doc.collection("transactions")
            .document(transaction.id.uuidString)
            .setData(payload, merge: true)
    }
    
    func fetchTransactions() async throws -> [RemoteTransaction] {
        let doc = try userDocument()
        let snapshot = try await doc.collection("transactions").getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String,
                  let amount = data["amount"] as? Double,
                  let frequency = data["frequency"] as? String,
                  let type = data["type"] as? String else {
                return nil
            }
            let budget = data["budget"] as? Double
            let date = (data["date"] as? Timestamp)?.dateValue()
            let uuid = UUID(uuidString: document.documentID) ?? UUID()
            return RemoteTransaction(
                id: uuid,
                name: name,
                amount: amount,
                frequency: frequency,
                type: type,
                date: date,
                budget: budget
            )
        }
    }
    
    func replaceLocalTransactions(with remote: [RemoteTransaction], in modelContext: ModelContext) async throws {
        try await MainActor.run {
            let fetchDescriptor = FetchDescriptor<TransactionItem>()
            if let existing = try? modelContext.fetch(fetchDescriptor) {
                existing.forEach { modelContext.delete($0) }
            }
            for transaction in remote {
                let newItem = TransactionItem(
                    id: transaction.id,
                    name: transaction.name,
                    amount: transaction.amount,
                    frequency: transaction.frequency,
                    type: transaction.type,
                    date: transaction.date,
                    budget: transaction.budget
                )
                modelContext.insert(newItem)
            }
            try modelContext.save()
        }
    }
    
    // MARK: - Bulk operations
    func restoreUserData(to modelContext: ModelContext) async {
        do {
            if let profile = try await fetchProfile() {
                profile.saveToDefaults()
            }
            let transactions = try await fetchTransactions()
            try await replaceLocalTransactions(with: transactions, in: modelContext)
        } catch {
            print("Failed to restore user data: \(error)")
        }
    }
    
    func clearRemoteData() async {
        do {
            let doc = try userDocument()
            let transactionSnapshot = try await doc.collection("transactions").getDocuments()
            for document in transactionSnapshot.documents {
                try await document.reference.delete()
            }
            try await doc.delete()
        } catch {
            print("Failed to clear remote data: \(error)")
        }
    }
}
