import SwiftUI
import SwiftData

// MARK: - SpendingIncomeTabsView

struct SpendingIncomeTabsView: View {
    @Query private var allItems: [TransactionItem]
    @Environment(\.modelContext) private var modelContext

    @State private var overallFrequency: String = "Annual"
    private let frequencyOptions = ["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"]

    // Updated to use the same keys as DashboardView
    private let spendingCategories: [String] = [
        "mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome",
        "groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving",
        "fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport",
        "streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"
    ]

    private let incomeCategories: [String] = [
        "salary", "interest", "investment", "otherIncome"
    ]

    // Mapping from keys to display names
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
        "otherPersonal": "Other entertainment & personal",
        
        // Income
        "salary": "Salary",
        "interest": "Interest",
        "investment": "Investment",
        "otherIncome": "Other income"
    ]

    private var spendingItems: [TransactionItem] {
        var items: [TransactionItem] = []

        for key in spendingCategories {
            if let existing = allItems.first(where: { $0.name == key && $0.type == "spending" }) {
                items.append(existing)
            } else {
                let newItem = TransactionItem(name: key, amount: 0, frequency: "Annual", type: "spending")
                modelContext.insert(newItem)
                items.append(newItem)
            }
        }

        // Save after all insertions
        do {
            try modelContext.save()
        } catch {
            print("Error saving inserted spending items: \(error)")
        }

        return items
    }

    private var incomeItems: [TransactionItem] {
        var items: [TransactionItem] = []

        for key in incomeCategories {
            if let existing = allItems.first(where: { $0.name == key && $0.type == "income" }) {
                items.append(existing)
            } else {
                let newItem = TransactionItem(name: key, amount: 0, frequency: "Annual", type: "income")
                modelContext.insert(newItem)
                items.append(newItem)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving inserted income items: \(error)")
        }

        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total spending: $\(formattedTotal(for: "spending"))")
                        Text("Total income: $\(formattedTotal(for: "income"))")
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

                TabView {
                    CategoryFormView(
                        title: "Spending",
                        items: spendingItems,
                        overallFrequency: $overallFrequency,
                        modelContext: modelContext,
                        displayNames: displayNames
                    )
                    .tag(0)

                    CategoryFormView(
                        title: "Income",
                        items: incomeItems,
                        overallFrequency: $overallFrequency,
                        modelContext: modelContext,
                        displayNames: displayNames
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            }
            .navigationTitle("My finances")
        }
    }

    private func formattedTotal(for type: String) -> String {
        let totalAnnual = allItems
            .filter { $0.type == type }
            .map { $0.amount * frequencyMultiplier(from: $0.frequency) }
            .reduce(0, +)

        let overallMult = frequencyMultiplier(from: overallFrequency)
        let converted = totalAnnual / overallMult
        return String(format: "%.2f", converted)
    }

    private func frequencyMultiplier(from freq: String) -> Double {
        switch freq {
        case "Weekly": return 52
        case "Fortnightly": return 26
        case "Monthly": return 12
        case "Quarterly": return 4
        case "Annual": return 1
        default: return 1
        }
    }
}

// MARK: - CategoryFormView

struct CategoryFormView: View {
    let title: String
    var items: [TransactionItem]

    @Binding var overallFrequency: String
    var modelContext: ModelContext
    let displayNames: [String: String]

    private let frequencyOptions = ["Weekly", "Fortnightly", "Monthly", "Quarterly", "Annual"]

    var body: some View {
        List {
            Section(header: Text(title).font(.headline)) {
                ForEach(items, id: \.id) { item in
                    HStack {
                        // Use display name if available, otherwise use the key
                        Text(displayNames[item.name] ?? item.name)
                            .frame(width: 140, alignment: .leading)

                        TextField("0", value: Binding(
                            get: { item.amount },
                            set: { newVal in
                                item.amount = newVal
                                save(item)
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)

                        Picker("", selection: Binding(
                            get: { item.frequency },
                            set: { newFreq in
                                item.frequency = newFreq
                                save(item)
                            }
                        )) {
                            ForEach(frequencyOptions, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    private func save(_ item: TransactionItem) {
        if item.id == UUID() {
            modelContext.insert(item)
        }
        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }
    }
}
