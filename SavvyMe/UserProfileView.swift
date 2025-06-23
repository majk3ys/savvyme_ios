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
    
    // Form validation and UI state
    @State private var showingSaveAlert = false
    @State private var showingClearAlert = false
    @State private var isFormValid = false
    
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
    
    var body: some View {
        NavigationView {
            Form {
                personalInfoSection
                householdInfoSection
                incomeSection
                
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

            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSavedProfile()
                validateForm()
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
    }
    
    // MARK: - Helper Functions
    var personalInfoSection: some View {
        Section(header: Text("Personal Information")) {
            HStack {
                Text("Age")
                Spacer()
                TextField("Enter age", text: $age)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: age) { _ in validateForm() }
            }

            HStack {
                Text("State/Territory")
                Spacer()
                Picker("", selection: $selectedState) {
                    ForEach(australianStates, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            HStack {
                Text("Postcode")
                Spacer()
                TextField("4-digit postcode", text: $postcode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: postcode) { _ in validateForm() }
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
                TextField("Number of adults", text: $adultsCount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: adultsCount) { _ in validateForm() }
            }

            HStack {
                Text("Children (under 15)")
                Spacer()
                TextField("Number of children", text: $childrenCount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: childrenCount) { _ in validateForm() }
            }
        }
    }

    var incomeSection: some View {
        Section(header: Text("Gross Annual Income"),
                footer: Text("Annual household income range")) {
            Picker("Income Range", selection: $selectedIncomeRange) {
                ForEach(incomeDisplayOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(WheelPickerStyle())
        }
    }


    private func validateForm() -> Void {
        let ageValid = age.isEmpty || (Int(age) != nil && Int(age)! > 0 && Int(age)! <= 120)
        let postcodeValid = postcode.isEmpty || (postcode.count == 4 && Int(postcode) != nil)
        let adultsValid = adultsCount.isEmpty || (Int(adultsCount) != nil && Int(adultsCount)! > 0)
        let childrenValid = childrenCount.isEmpty || (Int(childrenCount) != nil && Int(childrenCount)! >= 0)
        
        isFormValid = ageValid && postcodeValid && adultsValid && childrenValid
    }

    private func saveProfile() {
        // Save to UserDefaults
        UserDefaults.standard.set(age, forKey: "user_age")
        UserDefaults.standard.set(selectedState, forKey: "user_state")
        UserDefaults.standard.set(postcode, forKey: "user_postcode")
        UserDefaults.standard.set(maritalStatus, forKey: "user_marital_status")
        UserDefaults.standard.set(adultsCount, forKey: "user_adults_count")
        UserDefaults.standard.set(childrenCount, forKey: "user_children_count")
        UserDefaults.standard.set(selectedIncomeRange, forKey: "user_income_range")
        
        showingSaveAlert = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func loadSavedProfile() {
        age = UserDefaults.standard.string(forKey: "user_age") ?? ""
        selectedState = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        postcode = UserDefaults.standard.string(forKey: "user_postcode") ?? ""
        maritalStatus = UserDefaults.standard.string(forKey: "user_marital_status") ?? ""
        adultsCount = UserDefaults.standard.string(forKey: "user_adults_count") ?? ""
        childrenCount = UserDefaults.standard.string(forKey: "user_children_count") ?? ""
        selectedIncomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
    }
    
    private func clearAllData() {
        // Clear SwiftData transactions
        for item in allItems {
            modelContext.delete(item)
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
        
        validateForm()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
    }
}

// MARK: - Usage in existing app structure
/*
This UserProfileView is now fully integrated with your existing SwiftData setup.
It will:
- Clear both profile data (UserDefaults) and transaction data (SwiftData) when "Clear all data" is pressed
- Use the same navigation title "Profile" as your existing view
- Maintain the same structure and dependencies

The profile data is stored separately in UserDefaults and can be accessed anywhere in your app with:
let userAge = UserDefaults.standard.string(forKey: "user_age")
let userState = UserDefaults.standard.string(forKey: "user_state")
// etc.
*/
