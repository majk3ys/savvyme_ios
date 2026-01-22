//
//  ContentView.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import SwiftUI
import SwiftData
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var values: [String: String] = [:]
    @State private var frequencies: [String: String] = [:]
    @State private var overallFrequency: String = "Annual"
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var hasRestoredUserData = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [TransactionItem]
    @Query private var allGoals: [Goal]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                SpendingInputView(
                    overallFrequency: $overallFrequency,
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear
                )
                    .tabItem {
                        Label("My finances", systemImage: "square.and.pencil")
                    }

                DashboardView(
                    overallFrequency: $overallFrequency,
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear
                )
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }

                GoalsView(
                )
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }

                BlogView()
                    .tabItem {
                        Label("Blog", systemImage: "book")
                    }

                UserProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
            .accentColor(ColorTheme.primary)
            // ✅ Run notification checks once when the TabView appears
            .onAppear {
                runNotificationChecks()
                Task {
                    await UserDataService.shared.updateUserTimezone()
                }
                Task {
                    await restoreUserDataIfNeeded()
                }
            }

            ColorSchemeToggleButton()
                .padding(.top, 50)
                .padding(.trailing, 12)
            
            #if DEBUG
            Button("Run Notification Test") {
                runNotificationTest()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            #endif

        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a random test message!"
        content.sound = .default
        
        // Trigger after 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Test notification scheduled")
            }
        }
    }
    
    
    
    // MARK: - Debug Notification Tester
    private func runNotificationTest() {
        // Use actual transactions if you want realistic testing
        let transactions = allTransactions
        let goals = [
                Goal(
                    name: "Car test goal",
                    targetAmount: 2000,
                    currentAmount: 200,
                    category: "Car purchase",
                    deadline: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
                )
            ]

        let budgets = computeBudgets(transactions: transactions)
        let benchmarks = fetchBenchmarks()

        // Call your NotificationManager
        NotificationManager.shared.checkRules(
            transactions: transactions,
            goals: goals,
            budgets: budgets,
            benchmarks: benchmarks
        )

        print("✅ Goal test notification checkRules called")
    }

    // MARK: - Notification Check Function
    private func runNotificationChecks() {
        let transactions = allTransactions
        let goals = allGoals
        let budgets = computeBudgets(transactions: transactions)
        let benchmarks = fetchBenchmarks() // static for now
        
        NotificationManager.shared.checkRules(
            transactions: transactions,
            goals: goals,
            budgets: budgets,
            benchmarks: benchmarks
        )
    }
    
    private func computeBudgets(transactions: [TransactionItem]) -> [String: Double] {
        // Sum the budget per category (using transaction.type as category)
        var budgets: [String: Double] = [:]
        
        for transaction in transactions {
            let category = transaction.type
            if let budget = transaction.budget {
                budgets[category, default: 0] += budget
            }
        }
        
        return budgets
    }
    
    // MARK: - User data sync
    private func restoreUserDataIfNeeded() async {
        guard !hasRestoredUserData else { return }
        await UserDataService.shared.restoreUserData(to: modelContext)
        await MainActor.run {
            hasRestoredUserData = true
        }
    }
    
    let benchmarkManager = BenchmarkDataManager()

    func hasUserProfile() -> Bool {
        let state = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = UserDefaults.standard.string(forKey: "user_adults_count") ?? ""
        let childrenCount = UserDefaults.standard.string(forKey: "user_children_count") ?? ""
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        return state != "Any" && !adultsCount.isEmpty && !childrenCount.isEmpty && incomeRange != "Any"
    }

    func adjustedValue(for key: String, items: [TransactionItem], frequency: String) -> Double {
        guard let item = items.first(where: { $0.name == key }) else { return 0 }
        return item.amount * frequencyMultiplier(from: item.frequency) / frequencyMultiplier(from: frequency)
    }
    
    private func fetchBenchmarks() -> [String: Double] {
        guard hasUserProfile() else { return [:] }
        
        // Get user profile info from UserDefaults
        let userState = UserDefaults.standard.string(forKey: "user_state") ?? "Any"
        let adultsCount = Int(UserDefaults.standard.string(forKey: "user_adults_count") ?? "1") ?? 1
        let childrenCount = Int(UserDefaults.standard.string(forKey: "user_children_count") ?? "0") ?? 0
        let incomeRange = UserDefaults.standard.string(forKey: "user_income_range") ?? "Any"
        
        // Build a userSpending dictionary placeholder: we only need the keys for benchmarks
        var userSpending: [String: Double] = [:]
        
        // Build spending dictionary for benchmarks
        for category in AppCategories.spending.values.flatMap({ $0 }) {
            userSpending[category] = adjustedValue(
                for: category,
                items: allTransactions,        // <- pass transactions array here
                frequency: overallFrequency    // <- pass frequency here
            )
        }
        
        // Get benchmark comparisons
        let comparisons = benchmarkManager.getBenchmarkComparisons(
            userState: userState,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: incomeRange,
            userSpending: userSpending,
            overallFrequency: overallFrequency
        )
        
        // Convert comparisons into [Category: Amount] dictionary by summing subcategories
        var categoryBenchmarks: [String: Double] = [:]
        for comparison in comparisons {
            categoryBenchmarks[comparison.category, default: 0] += comparison.benchmarkAmount
        }
        
        return categoryBenchmarks
    }
}

extension Color {
    static let categoryColors: [String: Color] = [
        "Home": .blue,
        "Daily living": .green,
        "Transport": .orange,
        "Entertainment & personal": .purple,
        "Income": .mint
    ]

    static func shade(for category: String, index: Int, total: Int) -> Color {
        guard let base = categoryColors[category] else { return .gray }
        let fraction = Double(index) / Double(max(total - 1, 1))
        return base.opacity(0.5 + 0.5 * fraction) // Shades from 50% to 100%
    }
}


// MARK: - Time Selection Header
struct TimeSelectionHeader: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Binding var showingDatePicker: Bool
    
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var isCurrentMonth: Bool {
        selectedMonth == currentMonth && selectedYear == currentYear
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Previous month button
                Button(action: {
                    if selectedMonth == 1 {
                        selectedMonth = 12
                        selectedYear -= 1
                    } else {
                        selectedMonth -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Month/Year display - tappable to show picker
                Button(action: {
                    showingDatePicker = true
                }) {
                    VStack(spacing: 2) {
                        Text(monthNames[selectedMonth - 1])
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(String(selectedYear))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if isCurrentMonth {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(ColorTheme.primary)
                                    .frame(width: 5, height: 5)
                                Text("Current")
                                    .font(.caption2)
                                    .foregroundColor(ColorTheme.primary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Next month button
                Button(action: {
                    if selectedMonth == 12 {
                        selectedMonth = 1
                        selectedYear += 1
                    } else {
                        selectedMonth += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Binding var isPresented: Bool
    
    @State private var tempMonth: Int
    @State private var tempYear: Int
    
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    private let yearRange: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 2)...currentYear)
    }()
    
    init(selectedMonth: Binding<Int>, selectedYear: Binding<Int>, isPresented: Binding<Bool>) {
        self._selectedMonth = selectedMonth
        self._selectedYear = selectedYear
        self._isPresented = isPresented
        self._tempMonth = State(initialValue: selectedMonth.wrappedValue)
        self._tempYear = State(initialValue: selectedYear.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Month picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Month")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(1...12, id: \.self) { month in
                            Button(action: {
                                tempMonth = month
                            }) {
                                Text(monthNames[month - 1])
                                    .font(.subheadline)
                                    .foregroundColor(tempMonth == month ? .white : .primary)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(tempMonth == month ? ColorTheme.primary : Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Year picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Year")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(yearRange, id: \.self) { year in
                                Button(action: {
                                    tempYear = year
                                }) {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .foregroundColor(tempYear == year ? .white : .primary)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(tempYear == year ? ColorTheme.primary : Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Button("Done") {
                        selectedMonth = tempMonth
                        selectedYear = tempYear
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorTheme.primary)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 32) // Adds more space at bottom
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
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

// MARK: - Helper Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
