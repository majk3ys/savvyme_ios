import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftData

struct UserProfileRecord: Codable {
    var age: String
    var state: String
    var postcode: String
    var maritalStatus: String
    var adultsCount: String
    var childrenCount: String
    var incomeRange: String
    var lastUpdated: Date
}

struct TransactionRecord: Codable, Identifiable {
    var id: String
    var name: String
    var amount: Double
    var frequency: String
    var type: String
    var date: Date?
    var budget: Double?
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Profile
    func fetchUserProfile(userId: String) async throws -> UserProfileRecord? {
        let document = try await db
            .collection("users")
            .document(userId)
            .collection("private")
            .document("profile")
            .getDocument()

        guard document.exists else { return nil }
        return try document.data(as: UserProfileRecord.self)
    }

    func saveUserProfile(userId: String, profile: UserProfileRecord) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("private")
            .document("profile")
            .setData(from: profile, merge: true)
    }

    // MARK: - Transactions
    func fetchTransactions(userId: String) async throws -> [TransactionRecord] {
        let document = try await db
            .collection("users")
            .document(userId)
            .collection("private")
            .document("transactions")
            .getDocument()

        guard let rawItems = document.data()? ["items"] as? [[String: Any]] else { return [] }

        return rawItems.compactMap { item in
            guard
                let id = item["id"] as? String,
                let name = item["name"] as? String,
                let amount = item["amount"] as? Double,
                let frequency = item["frequency"] as? String,
                let type = item["type"] as? String
            else { return nil }

            let date: Date?
            if let timestamp = item["date"] as? Timestamp {
                date = timestamp.dateValue()
            } else if let storedDate = item["date"] as? Date {
                date = storedDate
            } else {
                date = nil
            }

            let budget = item["budget"] as? Double

            return TransactionRecord(
                id: id,
                name: name,
                amount: amount,
                frequency: frequency,
                type: type,
                date: date,
                budget: budget
            )
        }
    }

    func saveTransactions(userId: String, transactions: [TransactionRecord]) async throws {
        let payload: [[String: Any]] = transactions.map { record in
            var data: [String: Any] = [
                "id": record.id,
                "name": record.name,
                "amount": record.amount,
                "frequency": record.frequency,
                "type": record.type
            ]

            if let date = record.date {
                data["date"] = date
            }

            if let budget = record.budget {
                data["budget"] = budget
            }

            return data
        }

        try await db
            .collection("users")
            .document(userId)
            .collection("private")
            .document("transactions")
            .setData([
                "items": payload,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    // MARK: - SwiftData Sync Helpers
    func pushTransactionsFromLocal(userId: String, modelContext: ModelContext) async throws {
        let records: [TransactionRecord] = try await MainActor.run {
            let items = try modelContext.fetch(FetchDescriptor<TransactionItem>())
            return items.map { item in
                TransactionRecord(
                    id: item.id.uuidString,
                    name: item.name,
                    amount: item.amount,
                    frequency: item.frequency,
                    type: item.type,
                    date: item.date,
                    budget: item.budget
                )
            }
        }

        try await saveTransactions(userId: userId, transactions: records)
    }

    func pullTransactionsIntoLocal(userId: String, modelContext: ModelContext) async throws {
        let remoteRecords = try await fetchTransactions(userId: userId)

        try await MainActor.run {
            let existing = try modelContext.fetch(FetchDescriptor<TransactionItem>())
            var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            for record in remoteRecords {
                let uuid = UUID(uuidString: record.id) ?? UUID()
                let item: TransactionItem

                if let existingItem = existingById.removeValue(forKey: uuid) {
                    item = existingItem
                } else {
                    item = TransactionItem(
                        id: uuid,
                        name: record.name,
                        amount: record.amount,
                        frequency: record.frequency,
                        type: record.type,
                        date: record.date ?? Date(),
                        budget: record.budget
                    )
                    modelContext.insert(item)
                }

                // Update fields if they differ
                if item.name != record.name { item.name = record.name }
                if item.amount != record.amount { item.amount = record.amount }
                if item.frequency != record.frequency { item.frequency = record.frequency }
                if item.type != record.type { item.type = record.type }
                if item.date != record.date { item.date = record.date ?? Date() }
                if item.budget != record.budget { item.budget = record.budget }
            }

            // Keep any extra local transactions (offline entries) for now.
            try modelContext.save()
        }
    }
}
