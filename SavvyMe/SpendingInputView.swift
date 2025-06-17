import SwiftUI
import SwiftData

struct SpendingInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [TransactionItem]
    @Binding var overallFrequency: String
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = []
    @State private var selectedSegment = 0 // 0 for Spending, 1 for Income
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                                CategorySection(
                                    category: category,
                                    subcategories: currentCategories[category] ?? [],
                                    displayNames: currentDisplayNames,
                                    allItems: allItems,
                                    overallFrequency: overallFrequency,
                                    isExpanded: expandedCategories.contains(category),
                                    onToggleExpansion: { toggleCategory(category) },
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
                                allItems: allItems,
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
                expandedCategories.removeAll()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleCategory(_ category: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }
    
    private func updateItem(name: String, amount: Double, frequency: String) {
        let itemType = selectedSegment == 0 ? "spending" : "income"
        
        if let existingItem = allItems.first(where: { $0.name == name }) {
            existingItem.amount = amount
            existingItem.frequency = frequency
            existingItem.type = itemType
        } else {
            let newItem = TransactionItem(
                name: name,
                amount: amount,
                frequency: frequency,
                type: itemType
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
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentFrequency(for name: String) -> String {
        return allItems.first(where: { $0.name == name })?.frequency ?? overallFrequency
    }
    
    private func getCategoryTotal(for category: String) -> Double {
        let subcategories = currentCategories[category] ?? []
        return subcategories.reduce(0) { total, subcategory in
            total + getCurrentValue(for: subcategory)
        }
    }
}

// MARK: - Sub Views

private struct HeaderSection: View {
    @Binding var overallFrequency: String
    
    var body: some View {
        HStack {
            Text("Default frequency:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker("Frequency", selection: $overallFrequency) {
                ForEach(["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"], id: \.self) { freq in
                    Text(freq).tag(freq)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .font(.subheadline)
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
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(.blue)
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct CategorySection: View {
    let category: String
    let subcategories: [String]
    let displayNames: [String: String]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onUpdateItem: (String, Double, String) -> Void
    let isIncome: Bool
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Category header with swipe gesture
            CategoryHeader(
                category: category,
                total: getCategoryTotal(),
                isExpanded: isExpanded,
                onToggleExpansion: onToggleExpansion,
                isIncome: isIncome
            )
            .offset(x: dragOffset)
            .scaleEffect(isDragging ? 0.98 : 1.0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isDragging = true
                            }
                        }
                        dragOffset = value.translation.width * 0.3 // Reduce sensitivity
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isDragging = false
                            dragOffset = 0
                            
                            // Swipe to expand/collapse
                            if abs(value.translation.width) > 50 {
                                onToggleExpansion()
                            }
                        }
                    }
            )
            
            // Subcategories (expandable)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(subcategories, id: \.self) { subcategory in
                        ExpenseInputRow(
                            name: subcategory,
                            displayName: displayNames[subcategory] ?? subcategory,
                            currentValue: getCurrentValue(for: subcategory),
                            currentFrequency: getCurrentFrequency(for: subcategory),
                            defaultFrequency: overallFrequency,
                            onUpdateItem: onUpdateItem
                        )
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getCategoryTotal() -> Double {
        return subcategories.reduce(0) { total, subcategory in
            total + getCurrentValue(for: subcategory)
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentFrequency(for name: String) -> String {
        return allItems.first(where: { $0.name == name })?.frequency ?? overallFrequency
    }
}

private struct CategoryHeader: View {
    let category: String
    let total: Double
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let isIncome: Bool
    
    var body: some View {
        Button(action: onToggleExpansion) {
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
                
                // Swipe hint
                if !isExpanded {
                    Text("Swipe →")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
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
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                                saveValue()
                            }
                        }
                    }
                    .onSubmit {
                        saveValue()
                    }
                    .onChange(of: amountText) { _, newValue in
                        // Allow only valid decimal input
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            amountText = filtered
                        }
                    }
            }
            
            // Frequency picker (compact)
            Picker("", selection: $selectedFrequency) {
                ForEach(["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"], id: \.self) { freq in
                    Text(freq)
                        .font(.subheadline)
                        .tag(freq)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .font(.subheadline)
            .frame(width: 50)
            .onChange(of: selectedFrequency) { _, newValue in
                saveValue()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width * 0.2
                }
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dragOffset = 0
                        
                        // Swipe right to quick-set to common amount
                        if value.translation.width > 100 {
                            quickSetAmount()
                        }
                        // Swipe left to clear
                        else if value.translation.width < -100 {
                            clearAmount()
                        }
                    }
                }
        )
        .onAppear {
            amountText = currentValue > 0 ? String(format: "%.2f", currentValue) : ""
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
    
    private func quickSetAmount() {
        // Set common amounts based on category
        let commonAmounts: [String: Double] = [
            "rent": 500, "mortgage": 600, "groceries": 150,
            "electricity": 150, "fuel": 80, "phone": 50,
            "internet": 80, "salary": 1200, "wages": 800
        ]
        
        if let amount = commonAmounts[name] {
            amountText = String(format: "%.2f", amount)
            saveValue()
        }
    }
    
    private func clearAmount() {
        amountText = ""
        saveValue()
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

// MARK: - Extensions

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
