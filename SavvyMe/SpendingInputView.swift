import SwiftUI

struct SpendingIncomeTabsView: View {
    @Binding var values: [String: String]
    @Binding var frequencies: [String: String]
    @Binding var overallFrequency: String
    @State private var totalIncome: Double = 0.0
    @State private var totalSpending: Double = 0.0

    let incomeKeys = ["salary", "interest", "investment", "otherIncome"]
    let spendingKeys = [
        "mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome",
        "groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving",
        "fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport",
        "streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"
    ]

    private let frequencyOptions = ["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"]

    var body: some View {
        
        NavigationView {
            VStack(spacing: 12) {
                // Fixed totals and frequency picker in one horizontal row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total spending: $\(formattedNumber(totalSpending))")
                        Text("Total income: $\(formattedNumber(totalIncome))")
                    }
                    .font(.headline)

                    Spacer()

                    Picker("Frequency", selection: $overallFrequency) {
                        ForEach(frequencyOptions, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.horizontal)

                // Swipeable form content
                TabView {
                    CategoryFormView(
                        title: "Spending",
                        total: $totalSpending,
                        categories: [
                            "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome"],
                            "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
                            "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
                            "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"]
                        ],
                        categoryIcons: [
                            "Home": "house.fill",
                            "Daily living": "bag.fill",
                            "Transport": "car.fill",
                            "Entertainment & personal": "leaf.fill"
                        ],
                        categoryOrder: ["Home", "Daily living", "Transport", "Entertainment & personal"],
                        values: $values,
                        frequencies: $frequencies,
                        overallFrequency: $overallFrequency,
                        onChange: recalculateTotals,
                        submitURL: "https://savvyme.com/api/submit-spend"
                    )
                    .tag(0)

                    CategoryFormView(
                        title: "Income",
                        total: $totalIncome,
                        categories: [
                            "Income": ["salary", "interest", "investment", "otherIncome"]
                        ],
                        categoryIcons: [
                            "Income": "dollarsign.circle.fill"
                        ],
                        categoryOrder: ["Income"],
                        values: $values,
                        frequencies: $frequencies,
                        overallFrequency: $overallFrequency,
                        onChange: recalculateTotals,
                        submitURL: "https://savvyme.com/api/submit-income"
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("My finances")
            .hideKeyboardOnTap()
        }
        .onChange(of: overallFrequency) {
            recalculateTotals()
        }

    }

    enum ValueType {
        case income, spending
    }

    func formattedTotal(for type: ValueType) -> String {
        var total: Double = 0.0
        for (key, value) in values {
            guard let amount = Double(value), amount >= 0 else { continue }
            let freq = frequencies[key, default: "Annual"]
            let multiplier = frequencyMultiplier(from: freq)
            total += amount * multiplier
        }

        // You can extend this later to filter keys by type
        return "$\(formattedNumber(total))"
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
    
    func recalculateTotals() {
        totalIncome = calculateTotal(for: incomeKeys)
        totalSpending = calculateTotal(for: spendingKeys)
    }
    
    func calculateTotal(for keys: [String]) -> Double {
        var totalAnnual: Double = 0.0
        for key in keys {
            if let value = values[key], let amount = Double(value), amount >= 0 {
                let freq = frequencies[key, default: "Annual"]
                totalAnnual += amount * frequencyMultiplier(from: freq)
            }
        }
        // Now convert annual total to overallFrequency
        let overallMultiplier = frequencyMultiplier(from: overallFrequency)
        return totalAnnual / overallMultiplier
    }
}

struct CategoryFormView: View {
    let title: String
    @Binding var total: Double
    let categories: [String: [String]]
    let categoryIcons: [String: String]
    let categoryOrder: [String]
    @Binding var values: [String: String]
    @Binding var frequencies: [String: String]
    @Binding var overallFrequency: String
    let onChange: () -> Void
    let submitURL: String
   
    @AppStorage("userToken") private var userToken: String = ""
    @State private var expandedGroups: Set<String> = []

    private let frequencyOptions = ["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title above categories
            Text(title)
                .font(.title2)            // smaller than navigation title
                .fontWeight(.semibold)    // medium boldness
                .padding(.horizontal)
                .padding(.top, 24)

            Form {
                ForEach(categoryOrder, id: \.self) { group in
                    categorySection(for: group)
                }
            }
        }
        .savvyBackground()
    }
    
    @ViewBuilder
    func categorySection(for group: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // Custom tappable label
                HStack {
                    Image(systemName: categoryIcons[group] ?? "folder")
                        .foregroundColor(.accentColor)
                    Text(group)
                        .font(.headline)
                    Spacer()
                    Image(systemName: expandedGroups.contains(group) ? "chevron.down" : "chevron.right")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle()) // Makes the whole row tappable
                .onTapGesture {
                    if expandedGroups.contains(group) {
                        expandedGroups.remove(group)
                    } else {
                        expandedGroups.insert(group)
                    }
                }

                // Expandable content
                if expandedGroups.contains(group), let subcats = categories[group] {
                    ForEach(subcats, id: \.self) { subcat in
                        HStack {
                            Text(formatLabel(subcat))
                                .frame(width: 120, alignment: .leading)

                            TextField(
                                values[subcat, default: ""].isEmpty ? "0" : "",
                                text: Binding(
                                    get: { values[subcat, default: ""] },
                                    set: { newValue in
                                        let filtered = filterNumericInput(newValue, key: subcat)
                                        values[subcat] = filtered
                                        onChange()
                                    }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .font(.subheadline)

                            Picker("", selection: Binding(
                                get: { frequencies[subcat, default: "Annual"] },
                                set: {
                                    frequencies[subcat] = $0
                                    onChange()
                                }
                            )) {
                                ForEach(frequencyOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 110)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    func updateTotal() {
        // Collect all keys in the categories this form owns
        let ownedKeys = categories.values.flatMap { $0 }
        
        var totalValue = 0.0
        for key in ownedKeys {
            if let amountStr = values[key], let amount = Double(amountStr), amount >= 0 {
                let freq = frequencies[key, default: "Annual"]
                totalValue += amount * frequencyMultiplier(from: freq)
            }
        }
        total = totalValue
    }

    func filterNumericInput(_ input: String, key: String) -> String {
        let pattern = #"^\d*\.?\d{0,2}$"#
        if let _ = input.range(of: pattern, options: .regularExpression) {
            return input
        }
        return values[key, default: ""]
    }

    func formatLabel(_ key: String) -> String {
        let regex = try! NSRegularExpression(pattern: "([a-z])([A-Z])")
        let range = NSRange(location: 0, length: key.count)
        let formatted = regex.stringByReplacingMatches(in: key, options: [], range: range, withTemplate: "$1 $2")
        return formatted.capitalized
    }

    enum ValueType {
        case income, spending
    }

    func formattedTotal(for type: ValueType) -> String {
        var total: Double = 0.0
        for (key, value) in values {
            guard let amount = Double(value), amount >= 0 else { continue }
            let freq = frequencies[key, default: "Annual"]
            let multiplier = frequencyMultiplier(from: freq)
            total += amount * multiplier
        }

        // Type-based filtering if needed later
        return "$\(String(format: "%.2f", total))"
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

    func handleSubmit() {
        guard !userToken.isEmpty else { return }

        var payload: [String: [String: Any]] = [:]
        for (key, val) in values {
            if let value = Double(val), value >= 0 {
                let freq = frequencies[key, default: "Annual"]
                payload[key] = ["amount": value, "frequency": freq]
            }
        }

        guard let url = URL(string: submitURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch { return }

        URLSession.shared.dataTask(with: request).resume()
    }
}


extension View {
    func savvyBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(ColorTheme.background)
    }
    
    func hideKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}
