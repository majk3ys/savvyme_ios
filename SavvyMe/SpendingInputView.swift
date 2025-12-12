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
    @StateObject private var benchmarkManager = BenchmarkDataManager()
    
    var currentCategories: [String: [String]] {
        selectedSegment == 0 ? AppCategories.spending : AppCategories.income
    }
    
    var currentCategoryOrder: [String] {
        selectedSegment == 0 ? AppCategories.spendingOrder : AppCategories.incomeOrder
    }
    
    // Get items for the selected month/year - make it more efficient
    private var filteredItems: [TransactionItem] {
        let calendar = Calendar.current
        return allItems.filter { item in
            let itemDate = item.date ?? Date()
            let itemMonth = calendar.component(.month, from: itemDate)
            let itemYear = calendar.component(.year, from: itemDate)
            return itemMonth == selectedMonth && itemYear == selectedYear
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    
                    // Segment control for Income/Spending
                    Picker("Type", selection: $selectedSegment) {
                        Text("Spending").tag(0)
                        Text("Income").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    
                    // Overall budget progress bar (only for spending view)
                    if selectedSegment == 0 {
                        let totalBudget = getOverallBudgetTotal()
                        
                        if totalBudget > 0 {
                            let totalSpent = getOverallSpendingTotal()
                            let remaining = totalBudget - totalSpent
                            let progress = totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Budget: $\(formattedNumber(totalBudget))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("Remaining: $\(formattedNumber(remaining))")
                                        .font(.subheadline)
                                        .foregroundColor(remaining >= 0 ? .green : .red)
                                }
                                
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: progress > 1.0 ? .red : (progress > 0.8 ? .orange : .green)))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Time selector - positioned after the main header
                TimeSelectionHeader(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    showingDatePicker: $showingDatePicker
                )
                
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
                                    allItems: filteredItems,
                                    overallFrequency: overallFrequency,
                                    onUpdateItem: updateItem,
                                    onUpdateBudget: updateBudget,
                                    isIncome: selectedSegment == 1,
                                    selectedMonth: $selectedMonth,
                                    selectedYear: $selectedYear,
                                    showingDatePicker: $showingDatePicker,
                                    benchmarkManager: benchmarkManager
                                )
                            }
                        } else {
                            // Search results
                            SearchResultsSection(
                                searchText: searchText,
                                allCategories: currentCategories,
                                allItems: filteredItems,
                                overallFrequency: overallFrequency,
                                onUpdateItem: updateItem,
                                onUpdateBudget: updateBudget,
                                isIncome: selectedSegment == 1,
                                benchmarkManager: benchmarkManager
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
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedMonth: $selectedMonth,
                selectedYear: $selectedYear,
                isPresented: $showingDatePicker
            )
        }
    }
    
    // MARK: - Helper Functions
    private func updateItem(name: String, amount: Double) {
        let itemType = selectedSegment == 0 ? "spending" : "income"
        let frequency = "Monthly"
        
        // Create date for the selected month/year
        var dateComponents = DateComponents()
        dateComponents.year = selectedYear
        dateComponents.month = selectedMonth
        dateComponents.day = 1
        let selectedDate = Calendar.current.date(from: dateComponents) ?? Date()
        
        // Use a background queue for database operations
        Task { @MainActor in
            do {
                // Check if item exists for this specific month/year
                if let existingItem = filteredItems.first(where: { $0.name == name }) {
                    // Only update if value has changed
                    if existingItem.amount != amount {
                        existingItem.amount = amount
                        existingItem.frequency = frequency
                        existingItem.type = itemType
                        existingItem.date = selectedDate
                    }
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
                
                try modelContext.save()
            } catch {
                print("Error saving item: \(error)")
            }
        }
    }

    private func updateBudget(name: String, budget: Double) {
        let itemType = selectedSegment == 0 ? "spending" : "income"
        let frequency = "Monthly"
        
        // Create date for the selected month/year
        var dateComponents = DateComponents()
        dateComponents.year = selectedYear
        dateComponents.month = selectedMonth
        dateComponents.day = 1
        let selectedDate = Calendar.current.date(from: dateComponents) ?? Date()
        
        // Use a background queue for database operations
        Task { @MainActor in
            do {
                // Check if item exists for this specific month/year
                if let existingItem = filteredItems.first(where: { $0.name == name }) {
                    // Only update if budget has changed
                    let newBudget = budget > 0 ? budget : nil
                    if existingItem.budget != newBudget {
                        existingItem.budget = newBudget
                    }
                } else {
                    // Create new item with budget only if budget > 0
                    if budget > 0 {
                        let newItem = TransactionItem(
                            name: name,
                            amount: 0,
                            frequency: frequency,
                            type: itemType,
                            date: selectedDate,
                            budget: budget
                        )
                        modelContext.insert(newItem)
                    }
                }
                
                try modelContext.save()
            } catch {
                print("Error saving budget: \(error)")
            }
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return filteredItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentBudget(for name: String) -> Double {
        return filteredItems.first(where: { $0.name == name })?.budget ?? 0
    }
    
    private func getOverallBudgetTotal() -> Double {
        let allSpendingSubcategories = AppCategories.spending.values.flatMap { $0 }
        return allSpendingSubcategories.reduce(0) { total, subcategory in
            total + convertBudgetToOverallFrequency(for: subcategory)
        }
    }
    
    private func getOverallSpendingTotal() -> Double {
        let allSpendingSubcategories = AppCategories.spending.values.flatMap { $0 }
        return allSpendingSubcategories.reduce(0) { total, subcategory in
            total + convertToOverallFrequency(for: subcategory)
        }
    }
    
    private func convertToOverallFrequency(for name: String) -> Double {
        guard let item = filteredItems.first(where: { $0.name == name }) else { return 0 }
        let base = item.amount
        let fromMultiplier = frequencyMultiplier(from: "Monthly")
        let toMultiplier = frequencyMultiplier(from: overallFrequency)
        return base * fromMultiplier / toMultiplier
    }
    
    private func convertBudgetToOverallFrequency(for name: String) -> Double {
        guard let item = filteredItems.first(where: { $0.name == name }),
              let budget = item.budget else { return 0 }
        let fromMultiplier = frequencyMultiplier(from: "Monthly")
        let toMultiplier = frequencyMultiplier(from: overallFrequency)
        return budget * fromMultiplier / toMultiplier
    }
    
    private func getCategoryTotal(for category: String) -> Double {
        let subcategories = currentCategories[category] ?? []
        return subcategories.reduce(0) { total, subcategory in
            total + getCurrentValue(for: subcategory)
        }
    }
    
    private func formattedNumber(_ value: Double) -> String {
           let formatter = NumberFormatter()
           formatter.numberStyle = .decimal
           formatter.minimumFractionDigits = 0
           formatter.maximumFractionDigits = 0
           return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
       }
}

// MARK: - Sub Views

private struct HeaderSection: View {
    @Binding var overallFrequency: String
    
    var body: some View {
        HStack {
            Text("View frequency:")
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
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double) -> Void
    let onUpdateBudget: (String, Double) -> Void
    let isIncome: Bool
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Binding var showingDatePicker: Bool
    let benchmarkManager: BenchmarkDataManager
    
    var body: some View {
        NavigationLink(destination: CategoryDetailView(
            category: category,
            subcategories: subcategories,
            allItems: allItems,
            overallFrequency: overallFrequency,
            onUpdateItem: onUpdateItem,
            onUpdateBudget: onUpdateBudget,
            isIncome: isIncome,
            selectedMonth: $selectedMonth,
            selectedYear: $selectedYear,
            showingDatePicker: $showingDatePicker,
            benchmarkManager: benchmarkManager
        )) {
            VStack(spacing: 0) {
                HStack {
                    // Category color dot
                    Circle()
                        .fill(getCategoryColor())
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
    
    private func getCategoryColor() -> Color {
        // Fallback colors in case Color.categoryColors is not available
        switch category {
        case "Home": return .blue
        case "Daily living": return .green
        case "Transport": return .orange
        case "Entertainment & personal": return .purple
        case "Income": return .mint
        default: return .gray
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
        // Since all items are now stored as Monthly, convert from Monthly to the overallFrequency
        let fromMultiplier = frequencyMultiplier(from: "Monthly")
        let toMultiplier = frequencyMultiplier(from: overallFrequency)
        return base * fromMultiplier / toMultiplier
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    let category: String
    let subcategories: [String]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double) -> Void
    let onUpdateBudget: (String, Double) -> Void
    let isIncome: Bool
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Binding var showingDatePicker: Bool
    let benchmarkManager: BenchmarkDataManager
    
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var currentDisplayNames: [String: String] {
        isIncome ? AppCategories.incomeDisplayNames : AppCategories.spendingDisplayNames
    }
    
    var filteredSubcategories: [String] {
        if searchText.isEmpty {
            return subcategories.sorted { (currentDisplayNames[$0] ?? $0) < (currentDisplayNames[$1] ?? $1) }
        } else {
            return subcategories.filter { subcategory in
                let displayName = currentDisplayNames[subcategory] ?? subcategory
                return displayName.localizedCaseInsensitiveContains(searchText)
            }.sorted { (currentDisplayNames[$0] ?? $0) < (currentDisplayNames[$1] ?? $1) }
        }
    }
    
    // MARK: - Benchmark Helper Methods
    private func hasUserProfile() -> Bool {
        let state = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = UserDefaults.standard.string(forKey: "user_adults_count") ?? ""
        let childrenCount = UserDefaults.standard.string(forKey: "user_children_count") ?? ""
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        return state != "Any" && !adultsCount.isEmpty && !childrenCount.isEmpty && incomeRange != "Any"
    }
    
    private func getBenchmarkAmount(for subcategory: String) -> Double {
        //guard hasUserProfile() else { return 0 }
        
        let userState = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = Int(UserDefaults.standard.string(forKey: "user_adults_count") ?? "1") ?? 1
        let childrenCount = Int(UserDefaults.standard.string(forKey: "user_children_count") ?? "0") ?? 0
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        // Get benchmark data (this returns weekly amounts)
        let weeklyBenchmark = benchmarkManager.getBenchmarkAmount(
            for: subcategory,
            state: userState,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: incomeRange
        )
        
        // Convert from weekly to monthly (since we store budgets as monthly)
        let weeklyToMonthlyMultiplier = frequencyMultiplier(from: "Weekly") / frequencyMultiplier(from: "Monthly")
        return weeklyBenchmark * weeklyToMonthlyMultiplier
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with total - positioned after category name
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(getCategoryColor())
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
                
                // Budget summary - only show for spending when there are budgets
                if !isIncome {
                    let totalBudget = getCategoryBudgetTotal()
                    
                    if totalBudget > 0 {
                        let totalSpent = getCategoryTotal()
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Budget: $\(formattedNumber(totalBudget))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                let remaining = totalBudget - totalSpent
                                Text("Remaining: $\(formattedNumber(remaining))")
                                    .font(.subheadline)
                                    .foregroundColor(remaining >= 0 ? .green : .red)
                            }
                            
                            // Budget progress bar
                            let progress = totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: progress > 1.0 ? .red : (progress > 0.8 ? .orange : .green)))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Time selector - positioned after the category header
            TimeSelectionHeader(
                selectedMonth: $selectedMonth,
                selectedYear: $selectedYear,
                showingDatePicker: $showingDatePicker
            )
            
            // Search bar
            SearchBar(searchText: $searchText)
            
            // Header explanation
            HStack {
                Text("Enter monthly amounts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Subcategories list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSubcategories, id: \.self) { subcategory in
                        ExpenseInputRow(
                            name: subcategory,
                            displayName: currentDisplayNames[subcategory] ?? subcategory,
                            currentValue: getCurrentValue(for: subcategory),
                            currentBudget: getCurrentBudget(for: subcategory),
                            onUpdateItem: onUpdateItem,
                            onUpdateBudget: onUpdateBudget,
                            showBudget: !isIncome, // Always show budget for spending items
                            suggestedBudget: getBenchmarkAmount(for: subcategory)
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
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedMonth: $selectedMonth,
                selectedYear: $selectedYear,
                isPresented: $showingDatePicker
            )
        }
    }
    
    private func getCategoryColor() -> Color {
        switch category {
        case "Home": return .blue
        case "Daily living": return .green
        case "Transport": return .orange
        case "Entertainment & personal": return .purple
        case "Income": return .mint
        default: return .gray
        }
    }
    
    private func getCategoryTotal() -> Double {
        return subcategories.reduce(0) { total, subcategory in
            total + convertToOverallFrequency(for: subcategory)
        }
    }
    
    private func getCategoryBudgetTotal() -> Double {
        return subcategories.reduce(0) { total, subcategory in
            total + convertBudgetToOverallFrequency(for: subcategory)
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentBudget(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.budget ?? 0
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
        return base
    }
    
    private func convertBudgetToOverallFrequency(for name: String) -> Double {
        guard let item = allItems.first(where: { $0.name == name }),
        let budget = item.budget else { return 0 }
        return budget
    }
}

// MARK: - Updated ExpenseInputRow with Budget Suggestions
private struct ExpenseInputRow: View {
    let name: String
    let displayName: String
    let currentValue: Double
    let currentBudget: Double
    let onUpdateItem: (String, Double) -> Void
    let onUpdateBudget: (String, Double) -> Void
    let showBudget: Bool
    let suggestedBudget: Double
    
    @State private var amountText: String = ""
    @State private var budgetText: String = ""
    @State private var saveTimer: Timer?
    @State private var budgetSaveTimer: Timer?
    @State private var lastCurrentValue: Double = 0 // Track when external value changes
    @State private var lastCurrentBudget: Double = 0 // Track when external budget changes
    @State private var showBudgetSuggestion = false
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isBudgetFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Main input row
            HStack(spacing: 16) {
                // Subcategory name (takes available space)
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Input fields
                HStack(spacing: 12) {
                    // Spent input
                    VStack(alignment: .leading, spacing: 4) {
                        if showBudget {
                            Text("Spent")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        else {
                            Text("Earned")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 70)
                                .focused($isAmountFocused)
                                .onChange(of: amountText) { _, newValue in
                                    // Validate input
                                    let filtered = filterDecimalInput(newValue)
                                    if filtered != newValue {
                                        amountText = filtered
                                        return
                                    }
                                    
                                    // Debounce the save operation
                                    saveTimer?.invalidate()
                                    saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                        saveValue()
                                    }
                                }
                                .onSubmit {
                                    saveValue()
                                }
                        }
                    }
                    
                    // Budget input (show for spending items)
                    if showBudget {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Budget")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(ColorTheme.primary)
                                
                                // Show suggestion button if benchmark is available and no current budget
                                if suggestedBudget > 0 && currentBudget == 0 {
                                    Button(action: {
                                        showBudgetSuggestion.toggle()
                                    }) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("0", text: $budgetText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                                    .focused($isBudgetFocused)
                                    .onChange(of: budgetText) { _, newValue in
                                        // Validate input
                                        let filtered = filterDecimalInput(newValue)
                                        if filtered != newValue {
                                            budgetText = filtered
                                            return
                                        }
                                        
                                        // Debounce the save operation
                                        budgetSaveTimer?.invalidate()
                                        budgetSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                            saveBudget()
                                        }
                                    }
                                    .onSubmit {
                                        saveBudget()
                                    }
                            }
                        }
                    }
                }
            }
            
            // Budget suggestion row (only show when enabled and benchmark is available)
            if showBudgetSuggestion && suggestedBudget > 0 && showBudget {
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption)
                                    .foregroundColor(ColorTheme.primary)
                                
                                Text("Suggested budget")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Based on similar households in your area")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Set the benchmark amount as budget
                            let roundedAmount = round(suggestedBudget)
                            budgetText = String(format: "%.0f", roundedAmount)
                            onUpdateBudget(name, roundedAmount)
                            showBudgetSuggestion = false
                        }) {
                            HStack(spacing: 4) {
                                Text("$\(formattedNumber(suggestedBudget))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ColorTheme.primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showBudgetSuggestion)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            syncWithExternalState()
        }
        .onChange(of: currentValue) { _, newValue in
            // Update text field when external value changes (e.g., month change)
            if newValue != lastCurrentValue && !isAmountFocused {
                lastCurrentValue = newValue
                amountText = newValue > 0 ? String(format: "%.0f", newValue) : ""
            }
        }
        .onChange(of: currentBudget) { _, newValue in
            // Update text field when external budget changes (e.g., month change)
            if newValue != lastCurrentBudget && !isBudgetFocused {
                lastCurrentBudget = newValue
                budgetText = newValue > 0 ? String(format: "%.0f", newValue) : ""
                // Hide suggestion when budget is set
                if newValue > 0 {
                    showBudgetSuggestion = false
                }
            }
        }
        .onTapGesture {
            if !isAmountFocused && !isBudgetFocused {
                isAmountFocused = true
            }
        }
    }
    
    private func syncWithExternalState() {
        // Sync with external state on appear
        lastCurrentValue = currentValue
        lastCurrentBudget = currentBudget
        
        // Only update text if not currently being edited
        if !isAmountFocused {
            amountText = currentValue > 0 ? String(format: "%.0f", currentValue) : ""
        }
        if !isBudgetFocused {
            budgetText = currentBudget > 0 ? String(format: "%.0f", currentBudget) : ""
        }
        
        // Hide suggestion if budget is already set
        if currentBudget > 0 {
            showBudgetSuggestion = false
        }
    }
    
    private func filterDecimalInput(_ input: String) -> String {
        let allowedChars = "0123456789."
        let filtered = input.filter { allowedChars.contains($0) }
        
        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            return components[0] + "." + components[1]
        }
        
        return filtered
    }
    
    private func saveValue() {
        let amount = Double(amountText) ?? 0
        // Only save if the value has actually changed
        if amount != currentValue {
            lastCurrentValue = amount // Update our tracking
            onUpdateItem(name, amount)
        }
    }
    
    private func saveBudget() {
        let budget = Double(budgetText) ?? 0
        // Only save if the value has actually changed
        if budget != currentBudget {
            lastCurrentBudget = budget // Update our tracking
            onUpdateBudget(name, budget)
            // Hide suggestion after setting budget
            if budget > 0 {
                showBudgetSuggestion = false
            }
        }
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Updated SearchResultsSection with Budget Suggestions
private struct SearchResultsSection: View {
    let searchText: String
    let allCategories: [String: [String]]
    let allItems: [TransactionItem]
    let overallFrequency: String
    let onUpdateItem: (String, Double) -> Void
    let onUpdateBudget: (String, Double) -> Void
    let isIncome: Bool
    let benchmarkManager: BenchmarkDataManager
    
    var filteredItems: [(String, String, String)] { // (name, displayName, category)
        var results: [(String, String, String)] = []
        
        for (category, subcategories) in allCategories {
            for subcategory in subcategories {
                let displayName = AppCategories.spendingDisplayNames[subcategory] ?? subcategory
                if displayName.localizedCaseInsensitiveContains(searchText) {
                    results.append((subcategory, displayName, category))
                }
            }
        }
        
        return results.sorted { $0.1 < $1.1 } // Sort by display name
    }
    
    // MARK: - Benchmark Helper Methods
    private func hasUserProfile() -> Bool {
        let state = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = UserDefaults.standard.string(forKey: "user_adults_count") ?? ""
        let childrenCount = UserDefaults.standard.string(forKey: "user_children_count") ?? ""
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        return state != "Any" && !adultsCount.isEmpty && !childrenCount.isEmpty && incomeRange != "Any"
    }
    
    private func getBenchmarkAmount(for subcategory: String) -> Double {
        guard hasUserProfile() else { return 0 }
        
        let userState = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = Int(UserDefaults.standard.string(forKey: "user_adults_count") ?? "1") ?? 1
        let childrenCount = Int(UserDefaults.standard.string(forKey: "user_children_count") ?? "0") ?? 0
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        // Get benchmark data (this returns weekly amounts)
        let weeklyBenchmark = benchmarkManager.getBenchmarkAmount(
            for: subcategory,
            state: userState,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: incomeRange
        )
        
        // Convert from weekly to monthly (since we store budgets as monthly)
        let weeklyToMonthlyMultiplier = frequencyMultiplier(from: "Weekly") / frequencyMultiplier(from: "Monthly")
        return weeklyBenchmark * weeklyToMonthlyMultiplier
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
                                .fill(getCategoryColor(for: item.2))
                                .frame(width: 8, height: 8)
                            Text(item.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ExpenseInputRow(
                            name: item.0,
                            displayName: item.1,
                            currentValue: getCurrentValue(for: item.0),
                            currentBudget: getCurrentBudget(for: item.0),
                            onUpdateItem: onUpdateItem,
                            onUpdateBudget: onUpdateBudget,
                            showBudget: !isIncome, // Only show budget for spending items
                            suggestedBudget: getBenchmarkAmount(for: item.0)
                        )
                    }
                }
            }
        }
    }
    
    private func getCategoryColor(for category: String) -> Color {
        switch category {
        case "Home": return .blue
        case "Daily living": return .green
        case "Transport": return .orange
        case "Entertainment & personal": return .purple
        case "Income": return .mint
        default: return .gray
        }
    }
    
    private func getCurrentValue(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.amount ?? 0
    }
    
    private func getCurrentBudget(for name: String) -> Double {
        return allItems.first(where: { $0.name == name })?.budget ?? 0
    }
}
