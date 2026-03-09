import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [TransactionItem]

    // User profile data
    @State private var age: String = ""
    @State private var selectedState = "Any"
    @State private var postcode: String = ""
    @State private var maritalStatus = ""
    @State private var adultsCount: String = ""
    @State private var childrenCount: String = ""
    @State private var selectedIncomeRange = "Any"
    @State private var housingStatus = "renter"
    @State private var selectedMortgageBalanceGroup = "Any"
    
    // Form validation and UI state
    @State private var showingLogoutAlert = false
    @State private var showingSaveAlert = false
    @State private var showingClearAlert = false
    @State private var isFormValid = false
    @State private var isLoadingProfile = false
    
    // Australian states and territories
    let australianStates = [
        "Any", "NSW", "VIC", "QLD", "SA", "WA", "TAS", "NT", "ACT"
    ]
    
    let maritalOptions = ["Single", "Couple"]
    
    let incomeOptions = [
        "< 500": "< 25,000",
        "500-999": "25,000-49,999",
        "1,000-1,499": "50,000-79,999",
        "1,500-1,999": "80,000-104,999",
        "2,000-2,499": "105,000-129,999",
        "2,500-2,999": "130,000-159,999",
        "3,000-3,999": "160,000-209,999",
        ">= 4,000": ">= 210,000"
    ]
    
    let incomeDisplayOptions = ["Any"] + [
        "Below 25k",
        "25k-49k",
        "50k-79k",
        "80k-104k",
        "105k-129k",
        "130k-159k",
        "160k-209k",
        "210k above"
    ]
    

    let housingStatusOptions: [(value: String, label: String)] = [
        ("renter", "Renter"),
        ("owner_with_mortgage", "Owner with mortgage"),
        ("owner_no_mortgage", "Owner with no mortgage")
    ]
    
    var mortgageBalanceGroups: [String] {
        BenchmarkDataManager.shared.mortgageBalanceGroups
    }

    var body: some View {
        NavigationView {
            Form {
                personalInfoSection
                householdInfoSection
                incomeSection
                housingSection
                
                Section {
                    Button(action: {
                        saveProfile()
                    }) {
                        Text("Save profile")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!isFormValid)
                }

                Section {
                    Button(action: {
                        showingClearAlert = true
                    }) {
                        Text("Clear all data")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("Log out")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                validateForm()
                Task {
                    await loadProfile()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
        .alert("Profile saved", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text("Your profile has been saved successfully.")
        }
        .alert("Clear all data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your profile data and transaction data. This action cannot be undone.")
        }
        .alert("Log out of SavvyMe?", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) {
                logout()
            }
        } message: {
            Text("You’ll need to log in again to access your data.")
        }

    }
    
    // MARK: - Helper Functions
    var personalInfoSection: some View {
        Section(header: Text("Personal Information")) {
            HStack {
                Text("Age")
                Spacer()
                TextField("e.g. 32", text: $age)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    .onChange(of: age) { newValue in
                        age = numericPrefix(from: newValue, maxLength: 3)
                        validateForm()
                    }
            }

            if !age.isEmpty,
               let ageValue = Int(age),
               !(14...100).contains(ageValue) {
                Text("Enter a valid age between 14 and 100")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Menu {
                Picker("State/Territory", selection: $selectedState) {
                    ForEach(australianStates, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
            } label: {
                HStack {
                    Text("State")
                    Spacer()
                    Text(selectedState)
                        .fontWeight(.medium)
                }
                .foregroundColor(.nav)
            }

            HStack {
                Text("Postcode")
                Spacer()
                TextField("4-digit postcode", text: $postcode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onChange(of: postcode) { newValue in
                        postcode = numericPrefix(from: newValue, maxLength: 4)
                        validateForm()
                    }
            }

            if !postcode.isEmpty && (postcode.count != 4 || Int(postcode) == nil) {
                Text("Postcode must be 4 digits")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    var householdInfoSection: some View {
        Section(header: Text("Household Information")) {
            HStack {
                Text("Marital status")
                Spacer()
                Picker("Marital Status", selection: $maritalStatus) {
                    ForEach(maritalOptions, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Text("Adults (15+ years)")
                Spacer()
                TextField("e.g. 2", text: $adultsCount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .onChange(of: adultsCount) { newValue in
                        adultsCount = numericPrefix(from: newValue, maxLength: 2)
                        validateForm()
                    }
            }

            if !adultsCount.isEmpty,
               let adultsValue = Int(adultsCount),
               adultsValue < 1 {
                Text("At least 1 adult is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Text("Children (under 15)")
                Spacer()
                TextField("e.g. 0", text: $childrenCount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .onChange(of: childrenCount) { newValue in
                        childrenCount = numericPrefix(from: newValue, maxLength: 2)
                        validateForm()
                    }
            }
        }
    }

    var incomeSection: some View {
        Section(header: Text("Gross Annual Income"),
                footer: Text("Annual household income range")) {
            Menu {
                Picker("Income Range", selection: $selectedIncomeRange) {
                    ForEach(incomeDisplayOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } label: {
                HStack {
                    Text("Income range")
                    Spacer()
                    Text(selectedIncomeRange)
                        .fontWeight(.medium)
                }
                .foregroundColor(.nav)
            }
        }
    }

    var housingSection: some View {
        Section(header: Text("Housing")) {
            Menu {
                Picker("Housing status", selection: $housingStatus) {
                    ForEach(housingStatusOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            } label: {
                HStack {
                    Text("Housing status")
                    Spacer()
                    Text(housingStatusOptions.first(where: { $0.value == housingStatus })?.label ?? "Renter")
                        .fontWeight(.medium)
                }
                .foregroundColor(.nav)
            }

            if housingStatus == "owner_with_mortgage" {
                Menu {
                    Picker("Outstanding mortgage balance", selection: $selectedMortgageBalanceGroup) {
                        ForEach(mortgageBalanceGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                } label: {
                    HStack {
                        Text("Outstanding mortgage balance")
                        Spacer()
                        Text(selectedMortgageBalanceGroup)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.nav)
                }
            }
        }
    }

    private func validateForm() -> Void {
        let ageValid = age.isEmpty || (Int(age) != nil && Int(age)! > 0 && Int(age)! <= 120)
        let postcodeValid = postcode.isEmpty || (postcode.count == 4 && Int(postcode) != nil)
        let adultsValid = adultsCount.isEmpty || (Int(adultsCount) != nil && Int(adultsCount)! > 0)
        let childrenValid = childrenCount.isEmpty || (Int(childrenCount) != nil && Int(childrenCount)! >= 0)
        
        isFormValid = ageValid && postcodeValid && adultsValid && childrenValid
    }

    private func numericPrefix(from input: String, maxLength: Int) -> String {
        String(input.filter(\.isNumber).prefix(maxLength))
    }

    private func saveProfile() {
        let profile = UserProfileData(
            age: age,
            state: selectedState,
            postcode: postcode,
            maritalStatus: maritalStatus,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: selectedIncomeRange,
            housingStatus: housingStatus,
            mortgageBalanceGroup: housingStatus == "owner_with_mortgage" ? selectedMortgageBalanceGroup : "Any",
            updatedAt: Date()
        )

        profile.saveToDefaults()
        showingSaveAlert = true
        
        Task {
            do {
                try await UserDataService.shared.saveProfile(profile)
            } catch {
                print("Failed to save profile to cloud: \(error)")
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func loadProfile() async {
        await MainActor.run {
            isLoadingProfile = true
        }
        if let remoteProfile = try? await UserDataService.shared.fetchProfile() {
            remoteProfile.saveToDefaults()
            await MainActor.run {
                apply(profile: remoteProfile)
                isLoadingProfile = false
            }
            return
        }
        await MainActor.run {
            let cached = UserProfileData.fromDefaults()
            apply(profile: cached)
            isLoadingProfile = false
        }
    }

    private func apply(profile: UserProfileData) {
        age = profile.age
        selectedState = profile.state
        postcode = profile.postcode
        maritalStatus = profile.maritalStatus
        adultsCount = profile.adultsCount
        childrenCount = profile.childrenCount
        selectedIncomeRange = profile.incomeRange
        housingStatus = profile.housingStatus
        selectedMortgageBalanceGroup = profile.mortgageBalanceGroup
    }
    
    private func clearAllData() {
        // Clear SwiftData transactions
        for item in allItems {
            modelContext.delete(item)
        }
        
        // Clear SwiftData goals
        let fetchGoals = try? modelContext.fetch(FetchDescriptor<Goal>())
        if let goals = fetchGoals {
            for goal in goals {
                modelContext.delete(goal)
            }
        }
        try? modelContext.save()
        
        // Clear UserDefaults profile data
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            if key.hasPrefix("user_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        // Reset form fields
        age = ""
        selectedState = "Any"
        postcode = ""
        maritalStatus = ""
        adultsCount = ""
        childrenCount = ""
        selectedIncomeRange = "Any"
        housingStatus = "renter"
        selectedMortgageBalanceGroup = "Any"
        
        validateForm()

        Task {
            await UserDataService.shared.clearRemoteData()
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func logout() {
        do {
            try AuthService.shared.signOut()
            // ✅ App will automatically switch to AuthenticationView
            // via Firebase auth state listener
        } catch {
            print("Logout failed: \(error)")
        }
    }

}

// MARK: - Preview
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
    }
}
