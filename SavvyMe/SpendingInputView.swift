import SwiftUI
import SwiftData
import Foundation

struct SpendingInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [TransactionItem]
    @Binding var overallFrequency: String
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0 for Spending, 1 for Income
    @State private var showingDatePicker = false
    
    // Category structure matching your DashboardView
    private let spendingCategoryOrder = ["Home", "Daily living", "Transport", "Entertainment & personal"]
    private let incomeCategoryOrder = ["Income"]
    
    private let spendingCategories: [String: [String]] = [
        "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome"],
        "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
        "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
        "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"]
    ]
    
    private let incomeCategories: [String: [String]] = [
        "Income": ["salary", "investment", "interest", "otherIncome"]
    ]
    
    private let spendingDisplayNames: [String: String] = [
        // Home
        "mortgage": "Mortgage repayments",
        "rent": "Rent",
        "homeInsurance": "Home insurance",
        "electricity": "Electricity",
        "gas": "Gas",
        "water": "Water",
        "phone": "Phone",
        "internet": "Internet",
        "furniture": "Furniture",
        "otherHome": "Other home",
        
        // Daily living
        "groceries": "Groceries",
        "restaurants": "Restaurants and takeaway",
        "medical": "Medical services",
        "healthInsurance": "Health insurance",
        "education": "Education",
        "childCare": "Child care",
        "petCare": "Pet care",
        "otherDailyLiving": "Other daily living",
        
        // Transport
        "fuel": "Fuel",
        "servicing": "Servicing",
        "regoInsurance": "Rego/insurance",
        "publicTransport": "Public transport",
        "otherTransport": "Other transport",
        
        // Entertainment & personal
        "streaming": "Streaming services",
        "electronics": "Electronics",
        "concerts": "Concert/shows",
        "gymClubs": "Gym/clubs",
        "clothing": "Clothing",
        "salonBeauty": "Salon & beauty",
        "holidays": "Holidays",
        "otherPersonal": "Other entertainment & personal"
    ]
    
    private let incomeDisplayNames: [String: String] = [
        // Employment
        "salary": "Salary",
        "investment": "Investment",
        "interest": "Interest",
        "otherIncome": "Other income"
    ]
    
    var currentCategories: [String: [String]] {
        selectedSegment == 0 ? spendingCategories : incomeCategories
    }
    
    var currentCategoryOrder: [String] {
        selectedSegment == 0 ? spendingCategoryOrder : incomeCategoryOrder
    }
    
    var currentDisplayNames: [String: String] {
        selectedSegment == 0 ? spendingDisplayNames : incomeDisplayNames
    }
    
    // Get items for the selected month/year
    var filteredItems: [TransactionItem] {
        allItems.filter { item in
            let itemDate = item.date ?? Date()
            let itemMonth = Calendar.current.component(.month, from: itemDate)
            let itemYear = Calendar.current.component(.year, from: itemDate)
            return itemMonth == selectedMonth && itemYear == selectedYear
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time selector
                TimeSelectionHeader(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    showingDatePicker: $showingDatePicker
                )
                
                // Segment control for Income/Spending
                Picker("Type", selection: $selectedSegment) {
                    Text("Spending").tag(0)
                    Text("Income").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(.systemGray6))
                
                // Header with frequency selector
                HeaderSection(overallFrequency: $overallFrequency)
                
                // Search bar
                SearchBar(searchText: $searchText)
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if searchText.isEmpty {
                            // Category view
                            ForEach(currentCategoryOrder, id: \.self) { category in
                                CategoryCard(
                                    category: category,
                                    subcategories: currentCategories[category] ?? [],
                                    displayNames: currentDisplayNames,
                                    allItems: filteredItems,
                                    overallFrequency: overallFrequency,
                                    onUpdateItem: updateItem,
                                    isIncome: selectedSegment == 1
                                )
                            }
                        } else {
                            // Search results
                            SearchResultsSection(
                                searchText: searchText,
                                allCategories: currentCategories,
                                displayNames: currentDisplayNames,
                                allItems: filteredItems,
                                overallFrequency: overallFrequency,
                                onUpdateItem: updateItem,
                                isIncome: selectedSegment == 1
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(selectedSegment == 0 ? "Spending" : "Income")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: selectedSegment) { _, _ in
                // Clear search when switching segments
                searchText = ""
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    isPresented: $showingDatePicker
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    static func frequencyMultiplier(from freq: String) -> Double {
        switch freq {
        case "Weekly": return 52
        case "Fortnightly": return 26
        case "Monthly": return 12
        case "Quarterly": return 4
        case "Annual": return 1
        default: return 1
        }
    }

    private func updateItem(name: String, amount: Double, frequency: String) {
        let itemType = selectedSegment == 0 ? "spending" : "income"
        
        // Create date for the selected month/year
        var dateComponents = DateComponents()
        dateComponents.year = selectedYear
        dateComponents.month = selectedMonth
        dateComponents.day = 1
        let selectedDate = Calendar.current.date(from: dateComponents) ?? Date()
        
        // Check if item exists for this specific month/year
        if let existingItem = filteredItems.first(where: { $0.name == name }) {
            existingItem.amount = amount
            existingItem.frequency = frequency
            existingItem.type = itemType
            existingItem.date = selectedDate
        } else {
            let newItem = TransactionItem(
                name: name,
                amount: amount,
                frequency: frequency,
                type: itemType,
                date: selectedDate
            )
            modelContext.insert(newItem)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return filteredItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentFrequency(for name: String) -> String {
        return filteredItems.first(where: { $0.name == name })?.frequency ?? overallFrequency
    }
    
    private func getCategoryTotal(for category: String) -> Double {
        let subcategories = currentCategories[category] ?? []
        return subcategories.reduce(0) { total, subcategory in
            total + getCurrentValue(for: subcategory)
        }
    }
}
  
// MARK: - Sub Views (Updated to use filteredItems)

private struct HeaderSection: View {
    @Binding var overallFrequency: String
    
    var body: some View {
        HStack {
            Text("Select frequency:")
                .font(.subheadline)
            
            Spacer()
            
            Menu {
                ForEach(["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"], id: \.self) { freq in
                    Button(action: {
                        overallFrequency = freq
                    }) {
                        Text(freq)
                            .font(.subheadline)
                    }
                }
            } label: {
                HStack {
                    Text("\(overallFrequency)")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

private struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            VStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct CategoryCard: View {
    let category: String
    let subcategories: [String]
    let displayNames: [String: String]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double, String) -> Void
    let isIncome: Bool
    
    var body: some View {
        NavigationLink(destination: CategoryDetailView(
            category: category,
            subcategories: subcategories,
            displayNames: displayNames,
            allItems: allItems,
            overallFrequency: overallFrequency,
            onUpdateItem: onUpdateItem,
            isIncome: isIncome
        )) {
            VStack(spacing: 0) {
                HStack {
                    // Category color dot
                    Circle()
                        .fill(Color.categoryColors[category] ?? .gray)
                        .frame(width: 16, height: 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        let total = getCategoryTotal()
                        if total > 0 {
                            Text("$\(formattedNumber(total))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No \(isIncome ? "income" : "expenses") entered")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Show number of active items
                    let activeCount = getActiveItemCount()
                    if activeCount > 0 {
                        Text("\(activeCount) active")
                            .font(.caption)
                            .foregroundColor(ColorTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTheme.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getCategoryTotal() -> Double {
        return subcategories.reduce(0) { total, subcategory in
            total + convertToOverallFrequency(for: subcategory)
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getActiveItemCount() -> Int {
        return subcategories.filter { getCurrentValue(for: $0) > 0 }.count
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
    
    private func convertToOverallFrequency(for name: String) -> Double {
        guard let item = allItems.first(where: { $0.name == name }) else { return 0 }
        let base = item.amount
        let fromMultiplier = SpendingInputView.frequencyMultiplier(from: item.frequency)
        let toMultiplier = SpendingInputView.frequencyMultiplier(from: overallFrequency)
        return base * fromMultiplier / toMultiplier
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    let category: String
    let subcategories: [String]
    let displayNames: [String: String]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double, String) -> Void
    let isIncome: Bool
    
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var filteredSubcategories: [String] {
        if searchText.isEmpty {
            return subcategories.sorted { (displayNames[$0] ?? $0) < (displayNames[$1] ?? $1) }
        } else {
            return subcategories.filter { subcategory in
                let displayName = displayNames[subcategory] ?? subcategory
                return displayName.localizedCaseInsensitiveContains(searchText)
            }.sorted { (displayNames[$0] ?? $0) < (displayNames[$1] ?? $1) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with total
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.categoryColors[category] ?? .gray)
                        .frame(width: 20, height: 20)
                    
                    Text(category)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                
                HStack {
                    let total = getCategoryTotal()
                    Text("Total: $\(formattedNumber(total))")
                        .font(.headline)
                        .foregroundColor(total > 0 ? .primary : .secondary)
                    
                    Spacer()
                    
                    let activeCount = getActiveItemCount()
                    Text("\(activeCount) of \(subcategories.count) active")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Search bar
            SearchBar(searchText: $searchText)
            
            // Subcategories list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSubcategories, id: \.self) { subcategory in
                        ExpenseInputRow(
                            name: subcategory,
                            displayName: displayNames[subcategory] ?? subcategory,
                            currentValue: getCurrentValue(for: subcategory),
                            currentFrequency: getCurrentFrequency(for: subcategory),
                            defaultFrequency: overallFrequency,
                            onUpdateItem: onUpdateItem
                        )
                    }
                    
                    if filteredSubcategories.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No items found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
        }
    }
    
    private func getCategoryTotal() -> Double {
        return subcategories.reduce(0) { total, subcategory in
            total + convertToOverallFrequency(for: subcategory)
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentFrequency(for name: String) -> String {
        return allItems.first(where: { $0.name == name })?.frequency ?? overallFrequency
    }
    
    private func getActiveItemCount() -> Int {
        return subcategories.filter { getCurrentValue(for: $0) > 0 }.count
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
    
    private func convertToOverallFrequency(for name: String) -> Double {
        guard let item = allItems.first(where: { $0.name == name }) else { return 0 }
        let base = item.amount
        let fromMultiplier = SpendingInputView.frequencyMultiplier(from: item.frequency)
        let toMultiplier = SpendingInputView.frequencyMultiplier(from: overallFrequency)
        return base * fromMultiplier / toMultiplier
    }
}

private struct ExpenseInputRow: View {
    let name: String
    let displayName: String
    let currentValue: Double
    let currentFrequency: String
    let defaultFrequency: String
    let onUpdateItem: (String, Double, String) -> Void
    
    @State private var amountText: String = ""
    @State private var selectedFrequency: String = ""
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Expense name
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Amount input
                HStack(spacing: 4) {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .focused($isAmountFocused)
                        .onChange(of: amountText) { _, newValue in
                            // Allow only valid decimal input
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                amountText = filtered
                            }
                            saveValue()
                        }
                }
            }
            
            // Frequency picker (full width, smaller font)
            HStack {
                Spacer()
                
                Menu {
                    ForEach(["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"], id: \.self) { freq in
                        Button(action: {
                            selectedFrequency = freq
                            saveValue()
                        }) {
                            Text(freq)
                                .font(.subheadline)
                        }
                    }
                } label: {
                    HStack {
                        Text("\(selectedFrequency)")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            amountText = currentValue > 0 ? String(format: "%.0f", currentValue) : ""
            selectedFrequency = currentFrequency
        }
        .onTapGesture {
            if !isAmountFocused {
                isAmountFocused = true
            }
        }
    }
    
    private func saveValue() {
        let amount = Double(amountText) ?? 0
        onUpdateItem(name, amount, selectedFrequency)
    }
}

private struct SearchResultsSection: View {
    let searchText: String
    let allCategories: [String: [String]]
    let displayNames: [String: String]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double, String) -> Void
    let isIncome: Bool
    
    var filteredItems: [(String, String, String)] { // (name, displayName, category)
        var results: [(String, String, String)] = []
        
        for (category, subcategories) in allCategories {
            for subcategory in subcategories {
                let displayName = displayNames[subcategory] ?? subcategory
                if displayName.localizedCaseInsensitiveContains(searchText) {
                    results.append((subcategory, displayName, category))
                }
            }
        }
        
        return results.sorted { $0.1 < $1.1 } // Sort by display name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results (\(filteredItems.count))")
                .font(.headline)
                .padding(.horizontal)
            
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No \(isIncome ? "income sources" : "expenses") found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ForEach(filteredItems, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(Color.categoryColors[item.2] ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(item.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ExpenseInputRow(
                            name: item.0,
                            displayName: item.1,
                            currentValue: getCurrentValue(for: item.0),
                            currentFrequency: getCurrentFrequency(for: item.0),
                            defaultFrequency: overallFrequency,
                            onUpdateItem: onUpdateItem
                        )
                    }
                }
            }
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentFrequency(for name: String) -> String {
        return allItems.first(where: { $0.name == name })?.frequency ?? overallFrequency
    }
}
