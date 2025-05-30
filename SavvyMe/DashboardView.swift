import SwiftUI
import Charts

struct DashboardView: View {
    @Binding var values: [String: String]
    @Binding var frequencies: [String: String]
    @Binding var overallFrequency: String

    @State private var selectedCategory: String? = nil

    private let spendingCategories: [String: [String]] = [
        "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome"],
        "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
        "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
        "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"]
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Total section and frequency picker
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total spending: $\(formattedNumber(totalSpending()))")
                        Text("Total income: $\(formattedNumber(totalIncome()))")
                    }
                    .font(.headline)

                    Spacer()

                    Picker("Frequency", selection: $overallFrequency) {
                        ForEach(["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"], id: \ .self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.horizontal)

                GeometryReader { geometry in
                    ZStack {
                        Chart(pieData()) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Category", item.label))
                            .annotation(position: .overlay) {
                                if let percentage = item.percentage {
                                    Text("\(item.label): $\(formattedNumber(item.amount)) (\(percentage, specifier: "%.1f")%)")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.white.opacity(0.75))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                        }
                        .chartLegend(.hidden)
                        .padding()

                        VStack {
                            Text("Income")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("$\(formattedNumber(totalIncome()))")
                                .font(.title3)
                        }

                        // Overlay tap regions
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                let dx = location.x - center.x
                                let dy = location.y - center.y
                                let angle = atan2(dy, dx) * 180 / .pi
                                let normalizedAngle = angle < 0 ? angle + 360 : angle

                                var startAngle = 0.0
                                for item in pieData() {
                                    let sweep = (item.amount / pieData().map { $0.amount }.reduce(0, +)) * 360
                                    if normalizedAngle >= startAngle && normalizedAngle < startAngle + sweep {
                                        if selectedCategory == item.label {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = item.label
                                        }
                                        break
                                    }
                                    startAngle += sweep
                                }
                            }
                    }
                    .frame(height: 300)
                }

                Spacer()
            }
            .navigationTitle("Dashboard")
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
            let items = spendingCategories[selected]?.compactMap { subKey -> PieChartItem? in
                let amount = adjustedValue(for: subKey)
                return amount > 0 ? PieChartItem(label: formatLabel(subKey), amount: amount, percentage: nil) : nil
            } ?? []

            let total = items.map { $0.amount }.reduce(0, +)

            return items.map {
                PieChartItem(label: $0.label, amount: $0.amount, percentage: ($0.amount / total) * 100)
            }

        } else {
            let dict: [String: Double] = spendingCategories.mapValues { keys in
                keys.map { adjustedValue(for: $0) }.reduce(0, +)
            }

            let total = dict.values.reduce(0, +)

            return dict.map { (key, value) in
                PieChartItem(label: key, amount: value, percentage: (value / total) * 100)
            }
        }
    }

    func adjustedValue(for key: String) -> Double {
        guard let raw = values[key], let amount = Double(raw), amount >= 0 else { return 0 }
        let freq = frequencies[key, default: "Annual"]
        return amount * frequencyMultiplier(from: freq) / frequencyMultiplier(from: overallFrequency)
    }

    func totalIncome() -> Double {
        let incomeKeys = ["salary", "interest", "investment", "otherIncome"]
        return incomeKeys.reduce(0) { $0 + adjustedValue(for: $1) }
    }

    func totalSpending() -> Double {
        return spendingCategories.values.flatMap { $0 }.reduce(0) { $0 + adjustedValue(for: $1) }
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

    func formatLabel(_ key: String) -> String {
        let regex = try! NSRegularExpression(pattern: "([a-z])([A-Z])")
        let range = NSRange(location: 0, length: key.count)
        let formatted = regex.stringByReplacingMatches(in: key, options: [], range: range, withTemplate: "$1 $2")
        return formatted.capitalized
    }
}

