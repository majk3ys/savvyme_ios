import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @Binding var overallFrequency: String
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Query private var allItems: [TransactionItem]
    @State private var selectedCategory: String? = nil
    @State private var selectedSubcategory: String? = nil
    @State private var showingInsights = false
    @State private var showPercentages = false
    @State private var showBenchmarks = false
    @State private var showBudgets = false // New state for budget toggle
    @State private var showingDatePicker = false
    @State private var showTrendChartView = false
    @AppStorage("profile_last_updated") private var profileLastUpdated: TimeInterval = 0
    private let benchmarkManager = BenchmarkDataManager.shared
    @State private var benchmarkComparisons: [UserBenchmarkComparison] = []

    var filteredItems: [TransactionItem] {
        allItems.filter { item in
            let itemDate = item.date ?? Date()
            let itemMonth = Calendar.current.component(.month, from: itemDate)
            let itemYear = Calendar.current.component(.year, from: itemDate)
            return itemMonth == selectedMonth && itemYear == selectedYear
        }
    }

    private var adjustedAmountsByName: [String: Double] {
        filteredItems.reduce(into: [:]) { result, item in
            let adjustedAmount = item.amount * frequencyMultiplier(from: item.frequency) / frequencyMultiplier(from: overallFrequency)
            result[item.name, default: 0] += adjustedAmount
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    TimeSelectionHeader(
                        selectedMonth: $selectedMonth,
                        selectedYear: $selectedYear,
                        showingDatePicker: $showingDatePicker
                    )
                    HeaderSection(
                        totalIncome: totalIncome(),
                        totalSpending: totalSpending(),
                        remainingBudget: remainingBudget(),
                        totalBudget: getTotalBudget(),
                        overallFrequency: $overallFrequency
                    )

                    if hasSpendingData {
                        InsightsSection(
                            selectedCategory: selectedCategory,
                            largestExpenseCategory: largestExpenseCategory(),
                            savingsRate: savingsRate()
                        )
                    } else {
                        // Empty space instead of insight cards
                        HStack(spacing: 16) {
                            InsightCard(title: "Largest expense", value: "", icon: "exclamationmark.circle.fill", color: .orange)
                            InsightCard(title: "Savings rate", value: "", icon: "banknote.fill", color: .green)
                        }
                    }

                    Spacer()
                    
                    // Breakdown section
                    HStack {
                        Text("Spending analysis")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .layoutPriority(1)
                                                
                        if hasSpendingData {
                            AnalysisControls(
                                selectedCategory: $selectedCategory,
                                selectedSubcategory: $selectedSubcategory,
                                showTrendView: $showTrendChartView
                            )
                            .padding(.bottom)
                        } else {
                            Spacer()
                        }
                    }
                    
                    if hasSpendingData {
                        if selectedCategory == nil {
                            CategoryBreakdownSection(
                                categorySpending: categorySpending(),
                                totalSpending: totalSpending(),
                                overallFrequency: overallFrequency,
                                formattedNumber: formattedNumber,
                                selectedCategory: $selectedCategory,
                                benchmarkComparisons: benchmarkComparisons,
                                showBenchmarks: $showBenchmarks,
                                showBudgets: $showBudgets,
                                filteredItems: filteredItems
                            )
                        } else {
                            SubcategoryBreakdownSection(
                                selectedCategory: selectedCategory!,
                                selectedSubcategory: $selectedSubcategory,
                                selectedDate: selectedDate(),
                                getSubcategoryData: getSubcategoryData,
                                categorySpending: categorySpending(),
                                totalSpending: totalSpending(),
                                overallFrequency: overallFrequency,
                                formattedNumber: formattedNumber,
                                benchmarkComparisons: benchmarkComparisons,
                                showBenchmarks: $showBenchmarks,
                                showBudgets: $showBudgets,
                                filteredItems: filteredItems
                            )
                        }
                    }
                    
                    if hasSpendingData {
                        ChartSection(
                            selectedCategory: $selectedCategory,
                            selectedSubcategory: $selectedSubcategory,
                            showTrendChartView: $showTrendChartView,
                            pieData: pieData(),
                            categorySpending: categorySpending(),
                            totalSpending: totalSpending(),
                            formattedNumber: formattedNumber,
                            allItems: allItems,
                            selectedDate: selectedDate()
                        )
                        AIInsightSection(
                            selectedCategory: selectedCategory,
                            selectedSubcategory: selectedSubcategory,
                            benchmarkComparisons: benchmarkComparisons,
                            getThreeMonthTrendChange: getThreeMonthTrendChange,
                            currentAmountForKey: adjustedValue,
                            getBudgetForSubcategory: getBudgetForSubcategory,
                            getCategoryBudgetTotal: getCategoryBudgetTotal,
                            categorySpending: categorySpending,
                            getThreeMonthAverage: getThreeMonthAverage,
                            selectedFrequency: overallFrequency
                        )
                    } else {
                        VStack(spacing: 16) {
                            Text("No data available.\n Start entering your spending in \"My finances\"")
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                }
                .onAppear {
                   benchmarkComparisons = getBenchmarkComparisons()
                }
                .onChange(of: showBenchmarks) { newValue in
                    if newValue {
                        showBudgets = false // Turn off budgets when benchmarks are enabled
                        if benchmarkComparisons.isEmpty {
                            benchmarkComparisons = getBenchmarkComparisons()
                        }
                    }
                }
                .onChange(of: showBudgets) { newValue in
                    if newValue {
                        showBenchmarks = false // Turn off benchmarks when budgets are enabled
                    }
                }
                .onChange(of: overallFrequency) { _ in
                    // Recalculate benchmarks when frequency changes
                    benchmarkComparisons = getBenchmarkComparisons()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Insights") {
                        showingInsights.toggle()
                    }
                    .foregroundColor(.nav)
                }
            }
            .sheet(isPresented: $showingInsights) {
                InsightsView(
                    totalIncome: totalIncome(),
                    totalSpending: totalSpending(),
                    categories: categorySpending(),
                    frequency: overallFrequency
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    isPresented: $showingDatePicker
                )
            }
        }
        .id(profileLastUpdated) // <--- This forces view diffing/reconstruction
    }

    func selectedDate() -> Date {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // MARK: - Budget Methods
    
    private func hasBudgetData() -> Bool {
        return filteredItems.contains { $0.budget != nil && ($0.budget ?? 0) > 0 }
    }
    
    private func getBudgetForSubcategory(_ subcategory: String) -> Double {
        guard let budget = filteredItems.first(where: { $0.name == subcategory })?.budget else { return 0 }
        // Convert from Monthly (stored) to current frequency
        let fromMultiplier = frequencyMultiplier(from: "Monthly")
        let toMultiplier = frequencyMultiplier(from: overallFrequency)
        return budget * fromMultiplier / toMultiplier
    }
    
    private func getCategoryBudgetTotal(for category: String) -> Double {
        guard let subcategories = AppCategories.spending[category] else { return 0 }
        return subcategories.reduce(0) { total, subcategory in
            total + getBudgetForSubcategory(subcategory)
        }
    }
    
    private func getTotalBudget() -> Double {
        let allSpendingSubcategories = AppCategories.spending.values.flatMap { $0 }
        return allSpendingSubcategories.reduce(0) { total, subcategory in
            total + getBudgetForSubcategory(subcategory)
        }
    }
    
    // MARK: - Benchmark Methods
    
    private func hasUserProfile() -> Bool {
        let state = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = UserDefaults.standard.string(forKey: "user_adults_count") ?? ""
        let childrenCount = UserDefaults.standard.string(forKey: "user_children_count") ?? ""
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        return state != "Any" && !adultsCount.isEmpty && !childrenCount.isEmpty && incomeRange != "Any"
    }
    
    private func getBenchmarkComparisons() -> [UserBenchmarkComparison] {
        guard hasUserProfile() else { return [] }
        
        let userState = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = Int(UserDefaults.standard.string(forKey: "user_adults_count") ?? "1") ?? 1
        let childrenCount = Int(UserDefaults.standard.string(forKey: "user_children_count") ?? "0") ?? 0
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        // Create spending dictionary from current items
        var userSpending: [String: Double] = [:]
        for category in AppCategories.spending.values.flatMap({ $0 }) {
            userSpending[category] = adjustedValue(for: category)
        }
        
        let comparisons = benchmarkManager.getBenchmarkComparisons(
            userState: userState,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: incomeRange,
            userSpending: userSpending,
            overallFrequency: self.overallFrequency // This now uses the current frequency
        )
        
        // Convert benchmark amounts from weekly to current frequency
        let weeklyToCurrentMultiplier = frequencyMultiplier(from: "Weekly") / frequencyMultiplier(from: self.overallFrequency)
        
        return comparisons.map { comparison in
            UserBenchmarkComparison(
                category: comparison.category,
                subcategory: comparison.subcategory,
                userAmount: comparison.userAmount,
                benchmarkAmount: comparison.benchmarkAmount * weeklyToCurrentMultiplier,
                percentile: comparison.percentile,
                isAboveAverage: comparison.isAboveAverage,
                difference: comparison.difference * weeklyToCurrentMultiplier,
                percentageDifference: comparison.percentageDifference // Keep percentage the same
            )
        }
    }

    // MARK: - Existing Methods (unchanged)
    
    struct PieChartItem: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let percentage: Double?
    }

    func pieData() -> [PieChartItem] {
        if let selectedSubcatKey = selectedSubcategory {
            // Use key directly
            let amount = adjustedValue(for: selectedSubcatKey)
            if amount > 0 {
                let displayLabel = AppCategories.spendingDisplayNames[selectedSubcatKey] ?? selectedSubcatKey
                return [PieChartItem(label: displayLabel, amount: amount, percentage: 100)]
            } else {
                return []
            }
        } else if let selectedCat = selectedCategory {
            // Return all subcategories for that category (existing logic)
            let subItems = AppCategories.spending[selectedCat]?.compactMap { subKey -> PieChartItem? in
                let amount = adjustedValue(for: subKey)
                return amount > 0 ? PieChartItem(label: AppCategories.spendingDisplayNames[subKey] ?? subKey, amount: amount, percentage: nil) : nil
            } ?? []

            let total = subItems.map { $0.amount }.reduce(0, +)

            return subItems.map {
                PieChartItem(label: $0.label, amount: $0.amount, percentage: total > 0 ? ($0.amount / total) * 100 : 0)
            }
        } else {
            // Return all categories (existing logic)
            let totalDict: [String: Double] = AppCategories.spendingOrder.reduce(into: [:]) { result, key in
                let keys = AppCategories.spending[key] ?? []
                result[key] = keys.map { adjustedValue(for: $0) }.reduce(0, +)
            }

            let total = totalDict.values.reduce(0, +)

            return AppCategories.spendingOrder.compactMap { key in
                if let value = totalDict[key] {
                    return PieChartItem(label: key, amount: value, percentage: total > 0 ? (value / total) * 100 : 0)
                }
                return nil
            }
        }
    }

    func categorySpending() -> [String: Double] {
        return AppCategories.spendingOrder.reduce(into: [:]) { result, key in
            let keys = AppCategories.spending[key] ?? []
            result[key] = keys.map { adjustedValue(for: $0) }.reduce(0, +)
        }
    }

    func getSubcategoryData(for category: String) -> [PieChartItem] {
        guard let subKeys = AppCategories.spending[category] else { return [] }
       let subItems = subKeys.compactMap { subKey -> PieChartItem? in
           let amount = adjustedValue(for: subKey)
           return amount > 0 ? PieChartItem(label: AppCategories.spendingDisplayNames[subKey] ?? subKey, amount: amount, percentage: nil) : nil
       }
       let total = subItems.map { $0.amount }.reduce(0, +)
       return subItems.map {
           PieChartItem(label: $0.label, amount: $0.amount, percentage: total > 0 ? ($0.amount / total) * 100 : 0)
       }
    }
    
    func getMonthlyTrendChange(for key: String) -> Double? {
        let calendar = Calendar.current
        
        // Use selectedYear and selectedMonth to build selectedDate (start of month)
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        guard let selectedDate = calendar.date(from: components) else { return nil }
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) else { return nil }

        func totalForMonth(_ date: Date) -> Double {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            
            return allItems.filter { item in
                guard let itemDate = item.date else { return false }
                let itemYear = calendar.component(.year, from: itemDate)
                let itemMonth = calendar.component(.month, from: itemDate)
                return item.name == key && itemYear == year && itemMonth == month
            }
            .reduce(0) { partialResult, item in
                // Adjust amount to annual base and then scale to monthly
                let annualizedAmount = item.amount * frequencyMultiplier(from: item.frequency)
                return partialResult + (annualizedAmount / 12.0)
            }
        }

        let currentTotal = totalForMonth(selectedDate)
        let lastTotal = totalForMonth(lastMonthDate)

        guard lastTotal > 0 else { return nil }
        
        return ((currentTotal - lastTotal) / lastTotal) * 100
    }

    func getThreeMonthTrendChange(for key: String) -> Double? {
        let currentTotal = adjustedValue(for: key)
        guard currentTotal > 0 else { return nil }
        guard let averagePrevious = getThreeMonthAverage(for: key), averagePrevious > 0 else { return nil }

        return ((currentTotal - averagePrevious) / averagePrevious) * 100
    }

    func getThreeMonthAverage(for key: String) -> Double? {
        let calendar = Calendar.current
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        guard let selectedDate = calendar.date(from: components) else { return nil }

        func monthlyTotal(for date: Date) -> Double {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)

            return allItems
                .filter { item in
                    guard let itemDate = item.date else { return false }
                    let itemYear = calendar.component(.year, from: itemDate)
                    let itemMonth = calendar.component(.month, from: itemDate)
                    return item.name == key && itemYear == year && itemMonth == month
                }
                .reduce(0) { partialResult, item in
                    let annualizedAmount = item.amount * frequencyMultiplier(from: item.frequency)
                    return partialResult + (annualizedAmount / 12.0)
                }
        }

        let previousThreeMonths = (1...3).compactMap {
            calendar.date(byAdding: .month, value: -$0, to: selectedDate)
        }

        let previousTotals = previousThreeMonths.map(monthlyTotal)
        let averageMonthly = previousTotals.reduce(0, +) / Double(previousTotals.count)

        guard averageMonthly > 0 else { return nil }

        // Convert monthly baseline into the currently selected dashboard frequency.
        let convertedAverage = averageMonthly * frequencyMultiplier(from: "Monthly") / frequencyMultiplier(from: overallFrequency)
        return convertedAverage
    }

    func adjustedValue(for key: String) -> Double {
        adjustedAmountsByName[key] ?? 0
    }

    func totalIncome() -> Double {
        let incomeKeys = ["salary", "interest", "investment", "otherIncome"]
        return incomeKeys.reduce(0) { $0 + (adjustedAmountsByName[$1] ?? 0) }
    }

    func totalSpending() -> Double {
        let spendingKeys = AppCategories.spending.values.flatMap { $0 }
        return spendingKeys.reduce(0) { $0 + (adjustedAmountsByName[$1] ?? 0) }
    }

    func remainingBudget() -> Double {
        return totalIncome() - totalSpending()
    }

    func savingsRate() -> Double {
        let income = totalIncome()
        return income > 0 ? ((income - totalSpending()) / income) * 100 : 0
    }

    func largestExpenseCategory() -> String {
        let spending = categorySpending()
        return spending.max(by: { $0.value < $1.value })?.key ?? "None"
    }

    func budgetColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<100: return .green
        default: return .orange
        }
    }

    func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    func formattedNumberShort(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }

    func formatLabel(_ key: String) -> String {
        return AppCategories.spendingDisplayNames[key] ?? key.capitalized
    }
    
    var hasSpendingData: Bool {
        totalSpending() > 0
    }
}

// MARK: - Extracted Sub-views

// Replaces headerSection()
private struct HeaderSection: View {
    let totalIncome: Double
    let totalSpending: Double
    let remainingBudget: Double
    let totalBudget: Double
    @Binding var overallFrequency: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: .green,
                        label: "Income",
                        value: totalIncome,
                        formattedNumber: formattedNumber
                    )
                    
                    MetricRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: .red,
                        label: "Spending",
                        value: totalSpending,
                        formattedNumber: formattedNumber
                    )
                    
                    MetricRow(
                        icon: remainingBudget >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        iconColor: remainingBudget >= 0 ? .green : .orange,
                        label: "Net",
                        value: remainingBudget,
                        valueColor: remainingBudget >= 0 ? .primary : .red,
                        formattedNumber: formattedNumber
                    )
                }
                
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
            
            BudgetHealthIndicator(
                totalIncome: totalIncome,
                totalSpending: totalSpending,
                totalBudget: totalBudget,
                budgetColor: budgetColor
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
                
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
    
    private func budgetColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<100: return .green
        default: return .orange
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: Double
    var valueColor: Color = .primary // Optional for custom color, defaults to primary
    let formattedNumber: (Double) -> String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(formattedNumber(value))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
        }
    }
}

private struct BudgetHealthIndicator: View {
    let totalIncome: Double
    let totalSpending: Double
    let totalBudget: Double
    let budgetColor: (Double) -> Color

    var body: some View {
        // Use budget if available, otherwise fall back to income
        let referenceAmount = totalBudget > 0 ? totalBudget : totalIncome
        let percentage = totalSpending / max(referenceAmount, 1) * 100
        let isUsingBudget = totalBudget > 0
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isUsingBudget ? "Budget usage" : "Income usage")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(budgetColor(percentage))
            }
            
            ProgressView(value: min(percentage / 100, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: budgetColor(percentage)))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Show additional info when using budget
            if isUsingBudget {
                HStack {
                    Text("Budget: $\(formattedNumber(totalBudget))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let remaining = totalBudget - totalSpending
                    Text("Remaining: $\(formattedNumber(remaining))")
                        .font(.caption)
                        .foregroundColor(remaining >= 0 ? .green : .red)
                }
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



// Replaces chartSection()
private struct ChartSection: View {
    @Binding var selectedCategory: String?
    @Binding var selectedSubcategory: String?
    @Binding var showTrendChartView: Bool
    let pieData: [DashboardView.PieChartItem]
    let categorySpending: [String: Double]
    let totalSpending: Double
    let formattedNumber: (Double) -> String
    let allItems: [TransactionItem]
    let selectedDate: Date

    var body: some View {
        VStack(spacing: 12) {
            // Toggle button
            HStack {
                Spacer()
                Picker("", selection: $showTrendChartView) {
                    Text("Breakdown").tag(false)
                    Text("Trend").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.horizontal)
            
            if showTrendChartView {
                CategoryTrendChart(
                    allItems: allItems,
                    selectedCategory: selectedCategory,
                    selectedDate: selectedDate,
                    selectedSubcategory: $selectedSubcategory
                )
                .frame(height: 350)
            } else {
                ChartView(
                    selectedCategory: $selectedCategory,
                    selectedSubcategory: $selectedSubcategory,
                    pieData: pieData
                )
                .frame(height: 350)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private struct AnalysisControls: View {
    @Binding var selectedCategory: String?
    @Binding var selectedSubcategory: String?
    @Binding var showTrendView: Bool

    var body: some View {
        HStack {
            if let category = selectedCategory, let subcategory = selectedSubcategory {
                // Back to category from subcategory (only show in trend view)
                Button(action: { selectedSubcategory = nil }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to \(category)")
                    }
                    .font(.subheadline)
                }
                /*Spacer()
                Text(formattedLabel(from: subcategory))
                    .font(.headline)
                    .multilineTextAlignment(.trailing)*/
            } else if let category = selectedCategory {
                // Back to overview from category
                Button(action: { selectedCategory = nil }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to overview")
                    }
                    .font(.subheadline)
                }
                /*Spacer()
                Text(formattedLabel(from: category))
                    .font(.headline)
                    .multilineTextAlignment(.trailing)*/
            } else {
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    // CamelCase → "Title case"
    private func formattedLabel(from key: String) -> String {
        let spaced = key.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return spaced.prefix(1).capitalized + spaced.dropFirst().lowercased()
    }
}

private struct ChartView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedSubcategory: String?
    let pieData: [DashboardView.PieChartItem]

    var body: some View {
        Chart {
            ForEach(pieData, id: \.id) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(selectedCategory != nil ? 0.3 : 0.4),
                    angularInset: 2.0
                )
                .foregroundStyle(
                    (selectedCategory != nil || selectedSubcategory != nil)
                    ? Color.shade(for: selectedCategory ?? selectedSubcategory ?? "",
                                  index: pieData.firstIndex(where: { $0.id == item.id }) ?? 0,
                                  total: pieData.count)
                    : (Color.categoryColors[item.label] ?? .gray)
                )
                .position(by: .value("Category", item.label))
                .opacity(item.amount > 0 ? 1.0 : 0.1)
            }
        }
        .chartLegend(.visible)
        .chartAngleSelection(value: $selectedCategory)
        .animation(.easeInOut, value: selectedCategory)
    }
}

struct CategoryTrendChart: View {
    let allItems: [TransactionItem]
    let selectedCategory: String?
    let selectedDate: Date
    @Binding var selectedSubcategory: String?

    private var monthRange: [Date] {
        let calendar = Calendar.current
        return (-6...3).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: selectedDate)
        }
    }

    private func groupedData() -> [String: [Date: Double]] {
        let filteredItems = allItems.filter { $0.date != nil }

        let calendar = Calendar.current

        var result: [String: [Date: Double]] = [:]

        if let category = selectedCategory {
            // If a specific subcategory is selected, show only that one
            if let selectedSub = selectedSubcategory {
                for item in filteredItems where item.name == selectedSub {
                    guard let date = item.date else { continue }
                    let comps = calendar.dateComponents([.year, .month], from: date)
                    guard let monthStart = calendar.date(from: comps) else { continue }

                    let adjusted = item.amount * frequencyMultiplier(from: item.frequency) / 12
                    let label = item.name

                    result[label, default: [:]][monthStart, default: 0] += adjusted
                }
            } else {
                // Show all subcategories
                let subcategories = AppCategories.spending[category] ?? []

                for item in filteredItems where subcategories.contains(item.name) {
                    guard let date = item.date else { continue }
                    let comps = calendar.dateComponents([.year, .month], from: date)
                    guard let monthStart = calendar.date(from: comps) else { continue }

                    let adjusted = item.amount * frequencyMultiplier(from: item.frequency) / 12
                    let label = item.name

                    result[label, default: [:]][monthStart, default: 0] += adjusted
                }
            }
        } else {
            // Show top-level categories
            for item in filteredItems {
                guard let date = item.date else { continue }

                // Find which top-level category this item belongs to
                guard let category = AppCategories.spending.first(where: { $0.value.contains(item.name) })?.key else {
                    continue
                }

                let comps = calendar.dateComponents([.year, .month], from: date)
                guard let monthStart = calendar.date(from: comps) else { continue }

                let adjusted = item.amount * frequencyMultiplier(from: item.frequency) / 12

                result[category, default: [:]][monthStart, default: 0] += adjusted
            }
        }
        return result
    }

    private func colorForKey(_ key: String) -> Color {
        if let category = selectedCategory {
            // For subcategories, use shade colors
            let subcategories = AppCategories.spending[category] ?? []
            if let index = subcategories.firstIndex(of: key) {
                return Color.shade(for: category, index: index, total: subcategories.count)
            }
        } else {
            // For top-level categories, use category colors
            return Color.categoryColors[key] ?? .gray
        }
        return .gray
    }
    
    private func formattedLabel(from key: String) -> String {
        // Insert space before capital letters
        let spaced = key.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        // Capitalise first letter only
        return spaced.prefix(1).capitalized + spaced.dropFirst().lowercased()
    }

    var body: some View {
        let data = groupedData()
        let months = monthRange.sorted()

        VStack(spacing: 16) {
            Chart {
                ForEach(Array(data.keys), id: \.self) { key in
                    let values = months.map { date in
                        (date: date, value: data[key]?[date] ?? 0)
                    }

                    let label = formattedLabel(from: key)

                    ForEach(values, id: \.date) { entry in
                        LineMark(
                            x: .value("Month", entry.date),
                            y: .value("Value", entry.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Label", label)) // ✅ Legend uses label
                        .symbol(Circle())
                    }
                }

                if selectedCategory == nil || (selectedCategory != nil && selectedSubcategory == nil) {
                    let totalValues = months.map { date in
                        let total = data.values.reduce(0) { $0 + ($1[date] ?? 0) }
                        return (date: date, value: total)
                    }

                    ForEach(totalValues, id: \.date) { entry in
                        LineMark(
                            x: .value("Month", entry.date),
                            y: .value("Total", entry.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Label", "Total"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4]))
                        .symbol(Circle())
                    }
                }
            }
            .chartForegroundStyleScale { (label: String) in
                if label == "Total" {
                    return ColorTheme.nav
                }

                // Reverse-match label to key using formattedLabel
                let originalKey = data.keys.first(where: { formattedLabel(from: $0) == label }) ?? label
                return colorForKey(originalKey)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// AI insights for selected category or subcategory
struct AIInsightSection: View {
    let selectedCategory: String?
    let selectedSubcategory: String?
    let benchmarkComparisons: [UserBenchmarkComparison]
    let getThreeMonthTrendChange: (String) -> Double?
    let currentAmountForKey: (String) -> Double
    let getBudgetForSubcategory: (String) -> Double
    let getCategoryBudgetTotal: (String) -> Double
    let categorySpending: () -> [String: Double]
    let getThreeMonthAverage: (String) -> Double?
    let selectedFrequency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(insightLines().enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(line)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.top)

            Text(recommendationText())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
    }

    func insightLines() -> [String] {
        if let subcategory = selectedSubcategory {
            return subcategoryInsight(for: subcategory)
        }

        if let category = selectedCategory {
            return categoryInsight(for: category)
        }

        return overallInsight()
    }

    func recommendationText() -> String {
        if selectedSubcategory != nil {
            return "If this stays elevated next month, set a tighter cap for this subcategory and move spend to lower-priority areas."
        }

        if selectedCategory != nil {
            return "Focus first on the top one or two subcategories in this category—they usually give the biggest savings fastest."
        }

        return "Review the highest category each month, and set or update budgets where you are consistently above benchmarks."
    }

    private func formattedPercentFromRatio(_ value: Double) -> String {
        String(format: "%.0f%%", abs(value * 100))
    }

    private func formattedPercentValue(_ percentValue: Double) -> String {
        String(format: "%.0f%%", abs(percentValue))
    }

    private func frequencySuffix() -> String {
        switch selectedFrequency {
        case "Weekly":
            return "per week"
        case "Fortnightly":
            return "per fortnight"
        case "Quarterly":
            return "per quarter"
        case "Annual":
            return "per year"
        default:
            return "per month"
        }
    }

    private func subcategoryInsight(for key: String) -> [String] {
        let name = AppCategories.spendingDisplayNames[key] ?? key
        var statements: [String] = []

        let current = currentAmountForKey(key)
        if current > 0 {
            statements.append("\(name) is currently \(formattedCurrency(current)) \(frequencySuffix()).")
        }

        if let trend = getThreeMonthTrendChange(key), trend >= 20 {
            let averageText = getThreeMonthAverage(key).map { formattedCurrency($0) } ?? "$0"
            statements.append("This is up \(formattedPercentValue(trend)) versus your last 3-month average of \(averageText) \(frequencySuffix()).")
        }

        let budget = getBudgetForSubcategory(key)
        if budget > 0 {
            let delta = ((current - budget) / budget) * 100
            if delta >= 10 {
                statements.append("It is \(formattedPercentValue(delta)) above your budget.")
            }
        }

        if let comparison = benchmarkComparisons.first(where: { $0.subcategory == key }), comparison.percentageDifference >= 10 {
            statements.append("You're spending \(formattedPercentValue(comparison.percentageDifference)) above similar households.")
        }

        if statements.isEmpty {
            return ["\(name) spend is stable and close to your recent baseline."]
        }

        return statements
    }

    private func categoryInsight(for category: String) -> [String] {
        guard let subcategories = AppCategories.spending[category] else {
            return ["No insights are available for this category yet."]
        }

        let subSpending = subcategories
            .map { ($0, currentAmountForKey($0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        let categoryTotal = subSpending.reduce(0) { $0 + $1.1 }
        var statements: [String] = []

        if let top = subSpending.first, categoryTotal > 0 {
            let share = top.1 / categoryTotal
            let topName = AppCategories.spendingDisplayNames[top.0] ?? top.0
            statements.append("\(topName) is the biggest driver at \(formattedPercentFromRatio(share)) of \(category) spend.")
        }

        let categoryBudget = getCategoryBudgetTotal(category)
        if categoryBudget > 0, categoryTotal > categoryBudget {
            let over = ((categoryTotal - categoryBudget) / categoryBudget) * 100
            statements.append("\(category) is \(formattedPercentValue(over)) above your category budget.")
        }

        let benchmarkItems = benchmarkComparisons.filter { $0.category == category }
        let benchmarkTotal = benchmarkItems.reduce(0) { $0 + $1.benchmarkAmount }
        let userTotal = benchmarkItems.reduce(0) { $0 + $1.userAmount }
        if benchmarkTotal > 0 {
            let diff = ((userTotal - benchmarkTotal) / benchmarkTotal) * 100
            if diff >= 10 {
                statements.append("You're spending \(formattedPercentValue(diff)) above benchmark households in this category.")
            }
        }

        let spikingSubcategory = subcategories
            .map { ($0, getThreeMonthTrendChange($0) ?? 0) }
            .max(by: { $0.1 < $1.1 })

        if let spike = spikingSubcategory, spike.1 >= 25 {
            let spikeName = AppCategories.spendingDisplayNames[spike.0] ?? spike.0
            let averageText = getThreeMonthAverage(spike.0).map { formattedCurrency($0) } ?? "$0"
            statements.append("\(spikeName) shows a sudden spike of \(formattedPercentValue(spike.1)) against its 3-month average of \(averageText) \(frequencySuffix()).")
        }

        return statements.isEmpty
            ? ["\(category) spend looks steady with no major risk flags this month."]
            : statements
    }

    private func overallInsight() -> [String] {
        let categories = categorySpending()
        let sortedCategories = categories.sorted { $0.value > $1.value }
        let totalSpending = sortedCategories.reduce(0) { $0 + $1.value }
        var statements: [String] = []

        if let topCategory = sortedCategories.first, totalSpending > 0 {
            let share = topCategory.value / totalSpending
            statements.append("\(topCategory.key) is your largest spend category at \(formattedPercentFromRatio(share)) of total spending.")
        }

        if let highestBenchmarkGap = benchmarkComparisons.max(by: { $0.percentageDifference < $1.percentageDifference }),
           highestBenchmarkGap.percentageDifference >= 10 {
            let subName = AppCategories.spendingDisplayNames[highestBenchmarkGap.subcategory] ?? highestBenchmarkGap.subcategory
            statements.append("\(subName) is \(formattedPercentValue(highestBenchmarkGap.percentageDifference)) above similar-household benchmark.")
        }

        let allSubcategories = AppCategories.spending.values.flatMap { $0 }
        let biggestTrend = allSubcategories
            .map { ($0, getThreeMonthTrendChange($0) ?? 0) }
            .max(by: { $0.1 < $1.1 })

        if let trend = biggestTrend, trend.1 >= 25 {
            let name = AppCategories.spendingDisplayNames[trend.0] ?? trend.0
            let averageText = getThreeMonthAverage(trend.0).map { formattedCurrency($0) } ?? "$0"
            statements.append("Watch \(name): it's up \(formattedPercentValue(trend.1)) against its 3-month average of \(averageText) \(frequencySuffix()).")
        }

        return statements.isEmpty
            ? ["Your spending is broadly stable this month, with no major spikes versus recent history."]
            : statements
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

// Replaces insightsSection()
private struct InsightsSection: View {
    let selectedCategory: String?
    let largestExpenseCategory: String
    let savingsRate: Double

    var body: some View {
        HStack(spacing: 16) {
            InsightCard(
                title: "Largest expense",
                value: largestExpenseCategory,
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
            
            InsightCard(
                title: "Savings rate",
                value: "\(Int(savingsRate))%",
                icon: "banknote.fill",
                color: .green
            )
        }
    }
}

private struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Updated CategoryBreakdownSection
private struct CategoryBreakdownSection: View {
    let categorySpending:  [String: Double]
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    @Binding var selectedCategory: String?
    let benchmarkComparisons: [UserBenchmarkComparison]
    @Binding var showBenchmarks: Bool
    @Binding var showBudgets: Bool
    let filteredItems: [TransactionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All categories")
                    .font(.headline)
                
                Spacer()
                
                // Updated toggle buttons
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if showBenchmarks {
                                showBenchmarks = false
                            } else {
                                showBenchmarks = true
                                showBudgets = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showBenchmarks ? "chart.bar.fill" : "chart.bar")
                            Text("Benchmarks")
                        }
                        .font(.caption)
                        .foregroundColor(showBenchmarks ? .white : ColorTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(showBenchmarks ? ColorTheme.primary : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.primary, lineWidth: 1)
                        )
                    }
                    .disabled(benchmarkComparisons.isEmpty)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if showBudgets {
                                showBudgets = false
                            } else {
                                showBudgets = true
                                showBenchmarks = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showBudgets ? "target.fill" : "target")
                            Text("Budget")
                        }
                        .font(.caption)
                        .foregroundColor(showBudgets ? .white : ColorTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(showBudgets ? ColorTheme.primary : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.primary, lineWidth: 1)
                        )
                    }
                    .disabled(!hasBudgetData())
                }
            }
            .padding(.horizontal)
            
            // Show appropriate message
            if benchmarkComparisons.isEmpty {
                Text("Benchmarks unavailable. Finish completing your \"Profile\".")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            ForEach(AppCategories.spendingOrder, id: \.self) { category in
                let categoryTotal = categorySpending[category] ?? 0
                if categoryTotal > 0 {
                    CategoryRow(
                        category: category,
                        amount: categoryTotal,
                        totalSpending: totalSpending,
                        overallFrequency: overallFrequency,
                        formattedNumber: formattedNumber,
                        selectedCategory: $selectedCategory,
                        color: Color.categoryColors[category] ?? .gray,
                        benchmarkComparisons: benchmarkComparisons,
                        showBenchmarks: showBenchmarks,
                        showBudgets: showBudgets,
                        filteredItems: filteredItems
                    )
                }
            }
        }
    }
    
    private func hasBudgetData() -> Bool {
        return filteredItems.contains { $0.budget != nil && ($0.budget ?? 0) > 0 }
    }
}

// MARK: - Updated CategoryRow
private struct CategoryRow: View {
    let category: String
    let amount: Double
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    @Binding var selectedCategory: String?
    let color: Color
    let benchmarkComparisons: [UserBenchmarkComparison]
    let showBenchmarks: Bool
    let showBudgets: Bool
    let filteredItems: [TransactionItem]
    
    @State private var showTooltip = false
    
    private var categoryBenchmarks: [UserBenchmarkComparison] {
        let categorySubcategories = getCategorySubcategories(for: category)
        return benchmarkComparisons.filter { categorySubcategories.contains($0.subcategory) }
    }
    
    private var categoryBenchmarkTotal: Double {
        categoryBenchmarks.reduce(0) { $0 + $1.benchmarkAmount }
    }
    
    private var categoryBudgetTotal: Double {
        let categorySubcategories = getCategorySubcategories(for: category)
        return categorySubcategories.reduce(0) { total, subcategory in
            let budget = filteredItems.first(where: { $0.name == subcategory })?.budget ?? 0
            // Convert from Monthly (stored) to current frequency
            return total + (budget * frequencyMultiplier(from: "Monthly") / frequencyMultiplier(from: overallFrequency))
        }
    }

    private var isAboveBenchmark: Bool {
        categoryBenchmarkTotal > 0 && amount > categoryBenchmarkTotal
    }
    
    private var isOverBudget: Bool {
        categoryBudgetTotal > 0 && amount > categoryBudgetTotal
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedCategory = category
            }
        }) {
            VStack(spacing: 0) {
                // Main category row
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        let percentage = (amount / totalSpending) * 100
                        Text("\(Int(percentage))% of spending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(formattedNumber(amount))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(overallFrequency.lowercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
               
                // Benchmark or Budget comparison (when enabled)
                if showBenchmarks || showBudgets {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.top, 8)
                        
                        if showBenchmarks {
                            // Benchmark comparison view
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("vs Australian avg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: {
                                            showTooltip = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .resizable()
                                                .frame(width: 14, height: 14)
                                                .foregroundColor(ColorTheme.primary)
                                                .padding(.leading, 2)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: isAboveBenchmark ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                            .foregroundColor(isAboveBenchmark ? .red : .green)
                                            .font(.caption)
                                        
                                        Text("$\(formattedNumber(abs(amount - categoryBenchmarkTotal)))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(isAboveBenchmark ? .red : .green)
                                        
                                        Text(isAboveBenchmark ? "over" : "under")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("$\(formattedNumber(categoryBenchmarkTotal))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Benchmark progress bar
                            BenchmarkMiniProgressBar(
                                userAmount: amount,
                                benchmarkAmount: categoryBenchmarkTotal,
                                isAboveAverage: isAboveBenchmark
                            )
                        } else if showBudgets {
                            // Budget comparison view
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("vs budget")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: isOverBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                            .foregroundColor(isOverBudget ? .red : .green)
                                            .font(.caption)
                                        
                                        let remaining = categoryBudgetTotal - amount
                                        Text("$\(formattedNumber(abs(remaining)))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(isOverBudget ? .red : .green)
                                        
                                        Text(isOverBudget ? "over" : "remaining")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("$\(formattedNumber(categoryBudgetTotal))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Budget progress bar
                            BudgetMiniProgressBar(
                                spentAmount: amount,
                                budgetAmount: categoryBudgetTotal,
                                isOverBudget: isOverBudget
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTooltip) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Understanding this chart")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("• The colored bar shows your spending.")
                Text("• The vertical line shows the Australian household median (50th percentile).")
                Text("• Green = under benchmark, Red = over benchmark.")
                Text("• Benchmarks are based on similar Australian households, according to your profile e.g. 80% percentile means you spend more than 80% of similar households.")

                Spacer()

                Button("Close") {
                    showTooltip = false
                }
                .foregroundColor(ColorTheme.primary)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
    
    private func getCategorySubcategories(for category: String) -> [String] {
        return AppCategories.all[category] ?? []
    }
}

// MARK: - Updated SubcategoryBreakdownSection
private struct SubcategoryBreakdownSection: View {
    let selectedCategory: String?
    @Binding var selectedSubcategory: String?
    let selectedDate: Date
    let getSubcategoryData: (String) -> [DashboardView.PieChartItem]
    let categorySpending: [String: Double]
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    let benchmarkComparisons: [UserBenchmarkComparison]
    @Binding var showBenchmarks: Bool
    @Binding var showBudgets: Bool
    let filteredItems: [TransactionItem]
   
    var body: some View {
        if let selectedCategory = selectedCategory {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(selectedCategory)")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Updated toggle buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if showBenchmarks {
                                    showBenchmarks = false
                                } else {
                                    showBenchmarks = true
                                    showBudgets = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showBenchmarks ? "chart.bar.fill" : "chart.bar")
                                Text("Benchmarks")
                            }
                            .font(.caption)
                            .foregroundColor(showBenchmarks ? .white : ColorTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showBenchmarks ? ColorTheme.primary : Color.clear)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ColorTheme.primary, lineWidth: 1)
                            )
                        }
                        .disabled(benchmarkComparisons.isEmpty)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if showBudgets {
                                    showBudgets = false
                                } else {
                                    showBudgets = true
                                    showBenchmarks = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showBudgets ? "target.fill" : "target")
                                Text("Budget")
                            }
                            .font(.caption)
                            .foregroundColor(showBudgets ? .white : ColorTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showBudgets ? ColorTheme.primary : Color.clear)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ColorTheme.primary, lineWidth: 1)
                            )
                        }
                        .disabled(!hasBudgetData())
                    }
                }
                .padding(.horizontal)
                
                // Show appropriate message
                if benchmarkComparisons.isEmpty {
                    Text("Benchmarks unavailable. Finish completing your \"Profile\".")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                let subcategoryData = getSubcategoryData(selectedCategory)
                let categoryTotal = categorySpending[selectedCategory] ?? 0
                
                ForEach(subcategoryData.sorted(by: { $0.amount > $1.amount }), id: \.label) { item in
                    let index = subcategoryData.firstIndex(where: { $0.label == item.label }) ?? 0
                    let color = Color.shade(for: selectedCategory, index: index, total: subcategoryData.count)
                    
                    let subcategoryKey = findSubcategoryKey(for: item.label)
                    if item.amount > 0 && (selectedSubcategory == nil || selectedSubcategory == subcategoryKey) {
                            
                        SubcategoryRow(
                            label: item.label,
                            amount: item.amount,
                            categoryTotal: categoryTotal,
                            totalSpending: totalSpending,
                            overallFrequency: overallFrequency,
                            selectedCategory: selectedCategory,
                            selectedSubcategory: $selectedSubcategory,
                            selectedDate: selectedDate,
                            formattedNumber: formattedNumber,
                            color: color,
                            benchmarkComparisons: benchmarkComparisons,
                            subcategoryKey: subcategoryKey,
                            showBenchmarks: showBenchmarks,
                            showBudgets: showBudgets,
                            filteredItems: filteredItems
                        )
                    }
                }
            }
        }
    }
    
    private func findSubcategoryKey(for displayName: String) -> String {
        return AppCategories.spendingDisplayNames.first { $0.value == displayName }?.key ?? ""
    }
    
    private func hasBudgetData() -> Bool {
        return filteredItems.contains { $0.budget != nil && ($0.budget ?? 0) > 0 }
    }
}

// MARK: - Updated SubcategoryRow
private struct SubcategoryRow: View {
    let label: String
    let amount: Double
    let categoryTotal: Double
    let totalSpending: Double
    let overallFrequency: String
    let selectedCategory: String
    @Binding var selectedSubcategory: String?
    let selectedDate: Date
    let formattedNumber: (Double) -> String
    let color: Color
    let benchmarkComparisons: [UserBenchmarkComparison]
    let subcategoryKey: String
    let showBenchmarks: Bool
    let showBudgets: Bool
    let filteredItems: [TransactionItem]
    @State private var showTooltip = false
    
    private var benchmarkData: UserBenchmarkComparison? {
        benchmarkComparisons.first { $0.subcategory == subcategoryKey }
    }
    
    private var budgetAmount: Double {
        guard let budget = filteredItems.first(where: { $0.name == subcategoryKey })?.budget else { return 0 }
        // Convert from Monthly (stored) to current frequency
        return budget * frequencyMultiplier(from: "Monthly") / frequencyMultiplier(from: overallFrequency)
    }
    
    private var isOverBudget: Bool {
        budgetAmount > 0 && amount > budgetAmount
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedSubcategory = subcategoryKey
            }
        }) {
            VStack(spacing: 0) {
                // Main subcategory row
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            let categoryPercentage = categoryTotal > 0 ? (amount / categoryTotal) * 100 : 0
                            let totalPercentage = totalSpending > 0 ? (amount / totalSpending) * 100 : 0
                            
                            Text("\(String(format: "%.1f", categoryPercentage))% of \(selectedCategory)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(String(format: "%.1f", totalPercentage))% of total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(formattedNumber(amount))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(overallFrequency.lowercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedSubcategory == nil {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                // Benchmark or Budget comparison (when enabled)
                if (showBenchmarks && benchmarkData != nil) || (showBudgets && budgetAmount > 0) {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.top, 8)
                        
                        if showBenchmarks, let benchmark = benchmarkData {
                            // Benchmark comparison view
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("vs Australian avg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Button(action: {
                                            showTooltip = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .resizable()
                                                .frame(width: 14, height: 14)
                                                .foregroundColor(ColorTheme.primary)
                                                .padding(.leading, 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: benchmark.isAboveAverage ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                            .foregroundColor(benchmark.isAboveAverage ? .red : .green)
                                            .font(.caption)
                                        
                                        Text("$\(formattedNumber(abs(amount - benchmark.benchmarkAmount)))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(benchmark.isAboveAverage ? .red : .green)
                                        
                                        Text(benchmark.isAboveAverage ? "over" : "under")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(formattedNumber(benchmark.benchmarkAmount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let percentile = benchmark.percentile {
                                        Text("\(percentile)th percentile")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Benchmark progress bar
                            BenchmarkMiniProgressBar(
                                userAmount: amount,
                                benchmarkAmount: benchmark.benchmarkAmount,
                                isAboveAverage: benchmark.isAboveAverage
                            )
                        } else if showBudgets && budgetAmount > 0 {
                            // Budget comparison view
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("vs budget")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: isOverBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                            .foregroundColor(isOverBudget ? .red : .green)
                                            .font(.caption)
                                        
                                        let remaining = budgetAmount - amount
                                        Text("$\(formattedNumber(abs(remaining)))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(isOverBudget ? .red : .green)
                                        
                                        Text(isOverBudget ? "over" : "remaining")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("$\(formattedNumber(budgetAmount))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Budget progress bar
                            BudgetMiniProgressBar(
                                spentAmount: amount,
                                budgetAmount: budgetAmount,
                                isOverBudget: isOverBudget
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTooltip) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Understanding this chart")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("• The colored bar shows your spending.")
                Text("• The vertical line shows the Australian household median (50th percentile).")
                Text("• Green = under benchmark, Red = over benchmark.")
                Text("• Benchmarks are based on similar Australian households, according to your profile e.g. 80% percentile means you spend more than 80% of similar households.")

                Spacer()

                Button("Close") {
                    showTooltip = false
                }
                .foregroundColor(ColorTheme.primary)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
}

// MARK: - New BudgetMiniProgressBar component
private struct BudgetMiniProgressBar: View {
    let spentAmount: Double
    let budgetAmount: Double
    let isOverBudget: Bool
    
    private var maxAmount: Double {
        max(spentAmount, budgetAmount) * 1.1
    }
    
    private var spentProgress: Double {
        maxAmount > 0 ? spentAmount / maxAmount : 0
    }
    
    private var budgetProgress: Double {
        maxAmount > 0 ? budgetAmount / maxAmount : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Budget indicator line
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 1, height: 8)
                    .offset(x: budgetProgress * geometry.size.width - 0.5)
                
                // Spent progress bar
                Rectangle()
                    .fill(isOverBudget ?
                          LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: spentProgress * geometry.size.width, height: 4)
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.5), value: spentProgress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - New BenchmarkMiniProgressBar component
private struct BenchmarkMiniProgressBar: View {
    let userAmount: Double
    let benchmarkAmount: Double
    let isAboveAverage: Bool
    
    private var maxAmount: Double {
        max(userAmount, benchmarkAmount) * 1.1
    }
    
    private var userProgress: Double {
        maxAmount > 0 ? userAmount / maxAmount : 0
    }
    
    private var benchmarkProgress: Double {
        maxAmount > 0 ? benchmarkAmount / maxAmount : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Benchmark indicator line
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 1, height: 8)
                    .offset(x: benchmarkProgress * geometry.size.width - 0.5)
                
                // User progress bar
                Rectangle()
                    .fill(isAboveAverage ?
                          LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: userProgress * geometry.size.width, height: 4)
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.5), value: userProgress)
            }
        }
        .frame(height: 8)
    }
}


// MARK: - Insights View (No changes needed, but included for completeness)
struct InsightsView: View {
    let totalIncome: Double
    let totalSpending: Double
    let categories: [String: Double]
    let frequency: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
            
                    if totalSpending > 0 {
                        // Financial Health Score
                        FinancialHealthSection(
                            totalIncome: totalIncome,
                            totalSpending: totalSpending
                        )
                        
                        // Spending Trends
                        SpendingTrendsSection(
                            totalSpending: totalSpending,
                            categories: categories
                        )
                        
                        // Recommendations
                        RecommendationsSection(
                            totalIncome: totalIncome,
                            totalSpending: totalSpending,
                            categories: categories
                        )
                    }
                    else {
                        VStack(spacing: 16) {
                            Text("No data available.\n Start entering your spending in \"My finances\"")
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Smart insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primary)
                }
            }
        }
    }
    
    // Helper functions for insights
    private func calculateHealthScore(totalIncome: Double, totalSpending: Double) -> Double {
        let savingsRate = totalIncome > 0 ? ((totalIncome - totalSpending) / totalIncome) * 100 : 0
        let spendingRatio = totalIncome > 0 ? (totalSpending / totalIncome) * 100 : 100
        
        var score: Double = 50 // Base score
        
        // Savings rate scoring
        if savingsRate >= 20 { score += 30 }
        else if savingsRate >= 10 { score += 20 }
        else if savingsRate >= 5 { score += 10 }
        else if savingsRate < 0 { score -= 20 }
        
        // Spending ratio scoring
        if spendingRatio <= 50 { score += 20 }
        else if spendingRatio <= 80 { score += 10 }
        else if spendingRatio > 100 { score -= 30 }
        
        return max(0, min(100, score))
    }
    
    private func healthScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func healthScoreDescription(_ score: Double) -> String {
        switch score {
        case 80...100: return "Excellent financial health! You're managing your budget very well."
        case 60..<80: return "Good financial health with room for improvement."
        case 40..<60: return "Fair financial health. Consider reviewing your spending habits."
        default: return "Poor financial health. Time to make some changes to your budget."
        }
    }
    
    private func generateRecommendations(totalIncome: Double, totalSpending: Double, categories: [String: Double]) -> [String] {
        var recommendations: [String] = []
        
        let savingsRate = totalIncome > 0 ? ((totalIncome - totalSpending) / totalIncome) * 100 : 0
        
        if savingsRate < 10 {
            recommendations.append("Try to save at least 10% of your income. Consider reducing discretionary spending.")
        }
        
        if let highestCategory = categories.max(by: { $0.value < $1.value }) {
            let percentage = (highestCategory.value / totalSpending) * 100
            if percentage > 40 {
                recommendations.append("Your \(highestCategory.key) spending is quite high (\(Int(percentage))%). Look for ways to reduce costs in this category.")
            }
        }
        
        if totalSpending > totalIncome {
            recommendations.append("You're spending more than you earn. This is unsustainable - consider increasing income or reducing expenses.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Keep up the good work! Your budget looks well-balanced.")
        }
        
        return recommendations
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Insights Sub-views
private struct FinancialHealthSection: View {
    let totalIncome: Double
    let totalSpending: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financial health")
                .font(.title2)
                .fontWeight(.semibold)
            
            let healthScore = calculateHealthScore(totalIncome: totalIncome, totalSpending: totalSpending)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Overall score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(Int(healthScore))/100")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(healthScoreColor(healthScore))
                }
                
                Spacer()
                
                CircularProgressView(progress: healthScore / 100, color: healthScoreColor(healthScore))
                    .frame(width: 80, height: 80)
            }
            
            Text(healthScoreDescription(healthScore))
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func calculateHealthScore(totalIncome: Double, totalSpending: Double) -> Double {
        let savingsRate = totalIncome > 0 ? ((totalIncome - totalSpending) / totalIncome) * 100 : 0
        let spendingRatio = totalIncome > 0 ? (totalSpending / totalIncome) * 100 : 100
        
        var score: Double = 50 // Base score
        
        // Savings rate scoring
        if savingsRate >= 20 { score += 30 }
        else if savingsRate >= 10 { score += 20 }
        else if savingsRate >= 5 { score += 10 }
        else if savingsRate < 0 { score -= 20 }
        
        // Spending ratio scoring
        if spendingRatio <= 50 { score += 20 }
        else if spendingRatio <= 80 { score += 10 }
        else if spendingRatio > 100 { score -= 30 }
        
        return max(0, min(100, score))
    }
    
    private func healthScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func healthScoreDescription(_ score: Double) -> String {
        switch score {
        case 80...100: return "Excellent financial health! You're managing your budget very well."
        case 60..<80: return "Good financial health with room for improvement."
        case 40..<60: return "Fair financial health. Consider reviewing your spending habits."
        default: return "Poor financial health. Time to make some changes to your budget."
        }
    }
}

private struct SpendingTrendsSection: View {
    let totalSpending: Double
    let categories: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending analysis")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(categories.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                if amount > 0 {
                    SpendingCategoryInsight(category: category, amount: amount, totalSpending: totalSpending)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

private struct SpendingCategoryInsight: View {
    let category: String
    let amount: Double
    let totalSpending: Double
    
    var body: some View {
        let percentage = (amount / totalSpending) * 100
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(percentage))% of total spending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(formattedNumber(amount))")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

private struct RecommendationsSection: View {
    let totalIncome: Double
    let totalSpending: Double
    let categories: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(generateRecommendations(totalIncome: totalIncome, totalSpending: totalSpending, categories: categories), id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    Text(recommendation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func generateRecommendations(totalIncome: Double, totalSpending: Double, categories: [String: Double]) -> [String] {
        var recommendations: [String] = []
        
        let savingsRate = totalIncome > 0 ? ((totalIncome - totalSpending) / totalIncome) * 100 : 0
        
        if savingsRate < 10 {
            recommendations.append("Try to save at least 10% of your income. Consider reducing discretionary spending.")
        }
        
        if let highestCategory = categories.max(by: { $0.value < $1.value }) {
            let percentage = (highestCategory.value / totalSpending) * 100
            if percentage > 40 {
                recommendations.append("Your \(highestCategory.key) spending is quite high (\(Int(percentage))%). Look for ways to reduce costs in this category.")
            }
        }
        
        if totalSpending > totalIncome {
            recommendations.append("You're spending more than you earn. This is unsustainable - consider increasing income or reducing expenses.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Keep up the good work! Your budget looks well-balanced.")
        }
        
        return recommendations
    }
}


// MARK: - Circular Progress View (No changes needed, but included for completeness)
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.3)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
        }
    }
}
