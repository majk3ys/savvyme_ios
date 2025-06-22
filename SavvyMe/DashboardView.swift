import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @Binding var overallFrequency: String
    @Query private var allItems: [TransactionItem]
    @State private var selectedCategory: String? = nil
    @State private var showingInsights = false
    @State private var showPercentages = false

    private let categoryOrder = ["Home", "Daily living", "Transport", "Entertainment & personal"]

    private let spendingCategories: [String: [String]] = [
        "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome"],
        "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
        "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
        "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"]
    ]

    // Add the same display names mapping to DashboardView
    private let displayNames: [String: String] = [
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

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    HeaderSection(
                        totalIncome: totalIncome(),
                        totalSpending: totalSpending(),
                        remainingBudget: remainingBudget(),
                        overallFrequency: $overallFrequency
                    )

                    ChartSection(
                        selectedCategory: $selectedCategory,
                        showPercentages: $showPercentages,
                        pieData: pieData(),
                        categorySpending: categorySpending(),
                        totalSpending: totalSpending(),
                        formattedNumber: formattedNumber
                    )

                    InsightsSection(
                        selectedCategory: selectedCategory,
                        largestExpenseCategory: largestExpenseCategory(),
                        savingsRate: savingsRate()
                    )

                    if selectedCategory == nil {
                        CategoryBreakdownSection(
                            categoryOrder: categoryOrder,
                            categorySpending: categorySpending(),
                            totalSpending: totalSpending(),
                            overallFrequency: overallFrequency,
                            formattedNumber: formattedNumber,
                            selectedCategory: $selectedCategory
                        )
                    } else {
                        SubcategoryBreakdownSection(
                            selectedCategory: selectedCategory!,
                            getSubcategoryData: getSubcategoryData,
                            categorySpending: categorySpending(),
                            totalSpending: totalSpending(),
                            overallFrequency: overallFrequency,
                            formattedNumber: formattedNumber,
                            displayNames: displayNames
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Insights") {
                        showingInsights.toggle()
                    }
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
        }
    }

    struct PieChartItem: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let percentage: Double?
    }

    func pieData() -> [PieChartItem] {
        if let selected = selectedCategory {
            let subItems = spendingCategories[selected]?.compactMap { subKey -> PieChartItem? in
                let amount = adjustedValue(for: subKey)
                return amount > 0 ? PieChartItem(label: displayNames[subKey] ?? subKey, amount: amount, percentage: nil) : nil
            } ?? []

            let total = subItems.map { $0.amount }.reduce(0, +)

            return subItems.map {
                PieChartItem(label: $0.label, amount: $0.amount, percentage: total > 0 ? ($0.amount / total) * 100 : 0)
            }
        } else {
            let totalDict: [String: Double] = categoryOrder.reduce(into: [:]) { result, key in
                let keys = spendingCategories[key] ?? []
                result[key] = keys.map { adjustedValue(for: $0) }.reduce(0, +)
            }

            let total = totalDict.values.reduce(0, +)

            return categoryOrder.compactMap { key in
                if let value = totalDict[key] {
                    return PieChartItem(label: key, amount: value, percentage: total > 0 ? (value / total) * 100 : 0)
                }
                return nil
            }
        }
    }

    func categorySpending() -> [String: Double] {
        return categoryOrder.reduce(into: [:]) { result, key in
            let keys = spendingCategories[key] ?? []
            result[key] = keys.map { adjustedValue(for: $0) }.reduce(0, +)
        }
    }

    func getSubcategoryData(for category: String) -> [PieChartItem] {
       guard let subKeys = spendingCategories[category] else { return [] }
       let subItems = subKeys.compactMap { subKey -> PieChartItem? in
           let amount = adjustedValue(for: subKey)
           return amount > 0 ? PieChartItem(label: displayNames[subKey] ?? subKey, amount: amount, percentage: nil) : nil
       }
       let total = subItems.map { $0.amount }.reduce(0, +)
       return subItems.map {
           PieChartItem(label: $0.label, amount: $0.amount, percentage: total > 0 ? ($0.amount / total) * 100 : 0)
       }
    }

    func adjustedValue(for key: String) -> Double {
        guard let item = allItems.first(where: { $0.name == key }) else { return 0 }
        let freq = item.frequency
        return item.amount * frequencyMultiplier(from: freq) / frequencyMultiplier(from: overallFrequency)
    }

    func totalIncome() -> Double {
        let incomeKeys = ["salary", "interest", "investment", "otherIncome"]
        return allItems.filter { incomeKeys.contains($0.name) }.reduce(0) { $0 + adjustedValue(for: $1.name) }
    }

    func totalSpending() -> Double {
        let spendingKeys = spendingCategories.values.flatMap { $0 }
        return allItems.filter { spendingKeys.contains($0.name) }.reduce(0) { $0 + adjustedValue(for: $1.name) }
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
        case 0..<50: return .green
        case 50..<80: return .yellow
        case 80..<100: return .orange
        default: return .red
        }
    }

    func frequencyMultiplier(from frequency: String) -> Double {
        switch frequency {
        case "Weekly": return 52
        case "Fortnightly": return 26
        case "Monthly": return 12
        case "Quarterly": return 4
        case "Annual": return 1
        default: return 1
        }
    }

    func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func formattedNumberShort(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }

    func formatLabel(_ key: String) -> String {
        return displayNames[key] ?? key.capitalized
    }
}

// MARK: - Extracted Sub-views

// Replaces headerSection()
private struct HeaderSection: View {
    let totalIncome: Double
    let totalSpending: Double
    let remainingBudget: Double
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
                        label: "Remaining",
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    private func budgetColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50: return .green
        case 50..<80: return .yellow
        case 80..<100: return .orange
        default: return .red
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
    let budgetColor: (Double) -> Color

    var body: some View {
        let percentage = totalSpending / max(totalIncome, 1) * 100
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Budget usage")
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
        }
    }
}


// Replaces chartSection()
private struct ChartSection: View {
    @Binding var selectedCategory: String?
    @Binding var showPercentages: Bool
    let pieData: [DashboardView.PieChartItem] // Pass the already computed data
    let categorySpending: [String: Double]
    let totalSpending: Double
    let formattedNumber: (Double) -> String // Pass the function

    var body: some View {
        VStack {
            ChartControls(selectedCategory: $selectedCategory, showPercentages: $showPercentages)
                .padding(.horizontal)

            ChartView(
                selectedCategory: $selectedCategory,
                showPercentages: $showPercentages,
                pieData: pieData
            )
            .frame(height: 350)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private struct ChartControls: View {
    @Binding var selectedCategory: String?
    @Binding var showPercentages: Bool

    var body: some View {
        HStack {
            if selectedCategory != nil {
                Button(action: { selectedCategory = nil }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to overview")
                    }
                }
                Spacer()
                Text(selectedCategory ?? "")
                    .font(.headline)
            } else {
                Spacer()
            }
            
            //Button(action: { showPercentages.toggle() }) {
                //HStack {
                    //Image(systemName: showPercentages ? "percent" : "dollarsign.circle")
                //}
                //.foregroundColor(.blue)
                //.padding(.horizontal, 12)
                //.padding(.vertical, 6)
                //.background(Color.blue.opacity(0.1))
                //.cornerRadius(8)
            //}
        }
    }
}

private struct ChartView: View {
    @Binding var selectedCategory: String?
    @Binding var showPercentages: Bool
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
                    selectedCategory != nil
                    ? Color.shade(for: selectedCategory!, index: pieData.firstIndex(where: { $0.id == item.id }) ?? 0, total: pieData.count)
                    : (Color.categoryColors[item.label] ?? .gray)
                )
                .position(by: .value("Category", item.label)) // required
                .opacity(item.amount > 0 ? 1.0 : 0.1)
            }
        }
        .chartLegend(.visible)
        .chartAngleSelection(value: $selectedCategory)
        .animation(.easeInOut, value: selectedCategory)
    }
}

// Replaces insightsSection()
private struct InsightsSection: View {
    let selectedCategory: String?
    let largestExpenseCategory: String
    let savingsRate: Double

    var body: some View {
        if selectedCategory == nil {
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


// Replaces categoryBreakdownSection()
private struct CategoryBreakdownSection: View {
    let categoryOrder: [String]
    let categorySpending: [String: Double]
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    @Binding var selectedCategory: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(categoryOrder, id: \.self) { category in
                let categoryTotal = categorySpending[category] ?? 0
                if categoryTotal > 0 {
                    CategoryRow(
                        category: category,
                        amount: categoryTotal,
                        totalSpending: totalSpending,
                        overallFrequency: overallFrequency,
                        formattedNumber: formattedNumber,
                        selectedCategory: $selectedCategory,
                        color: Color.categoryColors[category] ?? .gray // <-- pass color
                    )
                }
            }
        }
    }
}

private struct CategoryRow: View {
    let category: String
    let amount: Double
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    @Binding var selectedCategory: String?
    let color: Color  // <-- New

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedCategory = category
            }
        }) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)  // Color dot
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
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Replaces subcategoryBreakdownSection()
private struct SubcategoryBreakdownSection: View {
    let selectedCategory: String?
    let getSubcategoryData: (String) -> [DashboardView.PieChartItem]
    let categorySpending: [String: Double]
    let totalSpending: Double
    let overallFrequency: String
    let formattedNumber: (Double) -> String
    let displayNames: [String: String]
   
    var body: some View {
        if let selectedCategory = selectedCategory { // <--- CHANGE IS HERE
            VStack(alignment: .leading, spacing: 12) {
                Text("\(selectedCategory) - breakdown")
                    .font(.headline)
                    .padding(.horizontal)
                
                let subcategoryData = getSubcategoryData(selectedCategory)
                let categoryTotal = categorySpending[selectedCategory] ?? 0
                
                ForEach(subcategoryData.sorted(by: { $0.amount > $1.amount }), id: \.label) { item in
                    let index = subcategoryData.firstIndex(where: { $0.label == item.label }) ?? 0
                    let color = Color.shade(for: selectedCategory, index: index, total: subcategoryData.count)

                    if item.amount > 0 { // This inner if is fine, it means it returns EmptyView implicitly if condition is false
                        SubcategoryRow(
                            label: item.label,
                            amount: item.amount,
                            categoryTotal: categoryTotal,
                            totalSpending: totalSpending,
                            overallFrequency: overallFrequency,
                            selectedCategory: selectedCategory,
                            formattedNumber: formattedNumber,
                            color: color // <-- pass shade color
                        )
                    }
                }
            }
        }
    }
}

private struct SubcategoryRow: View {
    let label: String
    let amount: Double
    let categoryTotal: Double
    let totalSpending: Double
    let overallFrequency: String
    let selectedCategory: String
    let formattedNumber: (Double) -> String
    let color: Color  // <-- New

    var body: some View {
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
                .padding()
            }
            .navigationTitle("Financial insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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

