// Goal.swift
import Foundation
import SwiftData
import SwiftUI

// MARK: - Goal Data Model
@Model
class Goal {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var category: String
    var deadline: Date
    var createdDate: Date
    var isCompleted: Bool
    var notes: String?
    
    init(name: String, targetAmount: Double, currentAmount: Double = 0, category: String, deadline: Date, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.category = category
        self.deadline = deadline
        self.createdDate = Date()
        self.isCompleted = false
        self.notes = notes
    }
    
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentAmount / targetAmount) * 100, 100)
    }
    
    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: now, to: deadline).day ?? 0
    }
    
    var monthsRemaining: Double {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.month, .day], from: now, to: deadline)
        let months = Double(components.month ?? 0)
        let days = Double(components.day ?? 0)
        return months + (days / 30.0) // Approximate days to month fraction
    }
    
    var requiredMonthlySavings: Double {
        let months = max(monthsRemaining, 0.1) // Prevent division by zero
        return remainingAmount / months
    }
    
    var isOnTrack: Bool {
        let expectedProgress = timeProgressPercentage
        return progressPercentage >= expectedProgress
    }
    
    var timeProgressPercentage: Double {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: createdDate, to: deadline).day ?? 1
        let elapsedDays = calendar.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
        return min(Double(elapsedDays) / Double(totalDays) * 100, 100)
    }
}

// MARK: - Goal Categories
struct GoalCategories {
    static let categories = [
        "Holiday/Recreation",
        "House Deposit",
        "Car Purchase",
        "Emergency Fund",
        "Education",
        "Wedding",
        "Investment",
        "Debt Payoff",
        "Retirement",
        "Other"
    ]
    
    static let categoryIcons: [String: String] = [
        "Holiday/recreation": "airplane",
        "House deposit": "house.fill",
        "Car curchase": "car.fill",
        "Emergency fund": "shield.fill",
        "Education": "graduationcap.fill",
        "Wedding": "heart.fill",
        "Investment": "chart.line.uptrend.xyaxis",
        "Debt payoff": "creditcard.fill",
        "Retirement": "figure.walk",
        "Other": "star.fill"
    ]
    
    static let categoryColors: [String: Color] = [
        "Holiday/recreation": .orange,
        "House deposit": .blue,
        "Car purchase": .red,
        "Emergency fund": .green,
        "Education": .purple,
        "Wedding": .pink,
        "Investment": .mint,
        "Debt payoff": .yellow,
        "Retirement": .indigo,
        "Other": .gray
    ]
}

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.deadline) private var goals: [Goal]
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Query private var allItems: [TransactionItem]
    
    @State private var showingAddGoal = false
    @State private var showingGoalDetail: Goal?
    @State private var selectedFilter = "All"
    
    private var filteredGoals: [Goal] {
        let activeGoals = goals.filter { !$0.isCompleted }
        
        if selectedFilter == "All" {
            return activeGoals
        } else {
            return activeGoals.filter { $0.category == selectedFilter }
        }
    }
    
    private var completedGoals: [Goal] {
        goals.filter { $0.isCompleted }
    }
    
    private var currentSavingsRate: Double {
        // Calculate current monthly savings based on income vs spending
        let calendar = Calendar.current
        let monthlyItems = allItems.filter { item in
            guard let itemDate = item.date else { return false }
            let itemMonth = calendar.component(.month, from: itemDate)
            let itemYear = calendar.component(.year, from: itemDate)
            return itemMonth == selectedMonth && itemYear == selectedYear
        }
        
        let monthlyIncome = monthlyItems.filter { ["salary", "interest", "investment", "otherIncome"].contains($0.name) }
            .reduce(0) { $0 + $1.amount }
        
        let monthlySpending = monthlyItems.filter { AppCategories.spending.values.flatMap { $0 }.contains($0.name) }
            .reduce(0) { $0 + $1.amount }
        
        return monthlyIncome - monthlySpending
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with savings summary
                GoalsSummaryHeader(
                    goals: filteredGoals,
                    currentSavingsRate: currentSavingsRate,
                    selectedFilter: $selectedFilter
                )
                
                // Filter picker
                GoalsFilterPicker(selectedFilter: $selectedFilter)
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if filteredGoals.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "target")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No goals yet")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Set your first financial goal and start tracking your progress!")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Add Goal") {
                                    showingAddGoal = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(ColorTheme.primary)
                            }
                            .padding(.vertical, 60)
                        } else {
                            // Active goals
                            ForEach(filteredGoals, id: \.id) { goal in
                                GoalCard(
                                    goal: goal,
                                    currentSavingsRate: currentSavingsRate,
                                    onTap: { showingGoalDetail = goal }
                                )
                            }
                            
                            // Completed goals section
                            if !completedGoals.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Completed Goals")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("\(completedGoals.count)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(6)
                                    }
                                    
                                    ForEach(completedGoals.prefix(3), id: \.id) { goal in
                                        CompletedGoalCard(goal: goal)
                                    }
                                    
                                    if completedGoals.count > 3 {
                                        Text("+ \(completedGoals.count - 3) more completed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                    }
                                }
                                .padding(.top, 20)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddGoal = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(ColorTheme.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView { goal in
                modelContext.insert(goal)
                try? modelContext.save()
            }
        }
        .sheet(item: $showingGoalDetail) { goal in
            GoalDetailView(goal: goal, currentSavingsRate: currentSavingsRate)
        }
    }
}

// MARK: - Goals Summary Header
private struct GoalsSummaryHeader: View {
    let goals: [Goal]
    let currentSavingsRate: Double
    @Binding var selectedFilter: String
    
    private var totalTargetAmount: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }
    
    private var totalCurrentAmount: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }
    
    private var totalRequiredMonthlySavings: Double {
        goals.reduce(0) { $0 + $1.requiredMonthlySavings }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Total progress
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(formattedNumber(totalCurrentAmount))")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("of $\(formattedNumber(totalTargetAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Current savings vs required
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(formattedNumber(totalRequiredMonthlySavings))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(currentSavingsRate >= totalRequiredMonthlySavings ? .green : .red)
                    
                    HStack(spacing: 4) {
                        Image(systemName: currentSavingsRate >= totalRequiredMonthlySavings ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(currentSavingsRate >= totalRequiredMonthlySavings ? .green : .orange)
                        
                        Text(currentSavingsRate >= totalRequiredMonthlySavings ? "On track" : "Behind")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Overall progress bar
            if totalTargetAmount > 0 {
                let overallProgress = totalCurrentAmount / totalTargetAmount
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Overall Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(overallProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorTheme.primary)
                    }
                    
                    ProgressView(value: overallProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: ColorTheme.primary))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Goals Filter Picker
private struct GoalsFilterPicker: View {
    @Binding var selectedFilter: String
    
    private var filterOptions: [String] {
        ["All"] + GoalCategories.categories
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filterOptions, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter)
                            .font(.subheadline)
                            .foregroundColor(selectedFilter == filter ? .white : ColorTheme.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? ColorTheme.primary : Color.clear)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(ColorTheme.primary, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Goal Card
private struct GoalCard: View {
    let goal: Goal
    let currentSavingsRate: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header with icon and basic info
                HStack {
                    // Category icon
                    Image(systemName: GoalCategories.categoryIcons[goal.category] ?? "star.fill")
                        .font(.title2)
                        .foregroundColor(GoalCategories.categoryColors[goal.category] ?? .gray)
                        .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(goal.category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatDeadline(goal.deadline))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Progress percentage
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(GoalCategories.categoryColors[goal.category] ?? .gray)
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    HStack {
                        Text("$\(formattedNumber(goal.currentAmount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("$\(formattedNumber(goal.targetAmount))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            // Progress
                            Rectangle()
                                .fill(GoalCategories.categoryColors[goal.category] ?? .gray)
                                .frame(width: geometry.size.width * (goal.progressPercentage / 100), height: 8)
                                .cornerRadius(4)
                                .animation(.easeInOut(duration: 0.5), value: goal.progressPercentage)
                        }
                    }
                    .frame(height: 8)
                }
                
                // Status and required savings
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: goal.isOnTrack ? "checkmark.circle.fill" : "clock.fill")
                                .font(.caption)
                                .foregroundColor(goal.isOnTrack ? .green : .orange)
                            
                            Text(goal.isOnTrack ? "On track" : "Behind schedule")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(goal.isOnTrack ? .green : .orange)
                        }
                        
                        Text("\(goal.daysRemaining) days remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Need to save")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("$\(formattedNumber(goal.requiredMonthlySavings))/month")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(currentSavingsRate >= goal.requiredMonthlySavings ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Completed Goal Card
private struct CompletedGoalCard: View {
    let goal: Goal
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough()
                
                Text("Completed • $\(formattedNumber(goal.targetAmount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(goal.category)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .opacity(0.7)
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Add Goal View
struct AddGoalView: View {
    let onSave: (Goal) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var selectedCategory = "Holiday/Recreation"
    @State private var deadline = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Name")
                            .font(.headline)
                        
                        TextField("e.g., Europe Trip, House Deposit", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Category selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(GoalCategories.categories, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Image(systemName: GoalCategories.categoryIcons[category] ?? "star.fill")
                                            .foregroundColor(selectedCategory == category ? .white : (GoalCategories.categoryColors[category] ?? .gray))
                                        
                                        Text(category)
                                            .font(.subheadline)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedCategory == category ? (GoalCategories.categoryColors[category] ?? .gray) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Target amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Amount")
                            .font(.headline)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $targetAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Current amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Amount (Optional)")
                            .font(.headline)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $currentAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Deadline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Date")
                            .font(.headline)
                        
                        DatePicker("Deadline", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                        
                        TextField("Add any notes about this goal...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .foregroundColor(ColorTheme.primary)
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        let target = Double(targetAmount) ?? 0
        let current = Double(currentAmount) ?? 0
        
        let goal = Goal(
            name: name,
            targetAmount: target,
            currentAmount: current,
            category: selectedCategory,
            deadline: deadline,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(goal)
        dismiss()
    }
}

// MARK: - Goal Detail View
struct GoalDetailView: View {
    let goal: Goal
    let currentSavingsRate: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingEditAmount = false
    @State private var newAmount = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with goal info
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: GoalCategories.categoryIcons[goal.category] ?? "star.fill")
                                .font(.system(size: 40))
                                .foregroundColor(GoalCategories.categoryColors[goal.category] ?? .gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text(goal.category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Progress overview
                        VStack(spacing: 12) {
                            HStack {
                                Text("$\(formattedNumber(goal.currentAmount))")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(GoalCategories.categoryColors[goal.category] ?? .gray)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(Int(goal.progressPercentage))%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    
                                    Text("complete")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("of $\(formattedNumber(goal.targetAmount)) target")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 12)
                                        .cornerRadius(6)
                                    
                                    Rectangle()
                                        .fill(GoalCategories.categoryColors[goal.category] ?? .gray)
                                        .frame(width: geometry.size.width * (goal.progressPercentage / 100), height: 12)
                                        .cornerRadius(6)
                                        .animation(.easeInOut(duration: 0.5), value: goal.progressPercentage)
                                }
                            }
                            .frame(height: 12)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Stats cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        GoalStatCard(
                            title: "Remaining",
                            value: "$\(formattedNumber(goal.remainingAmount))",
                            icon: "target",
                            color: .orange
                        )
                        
                        GoalStatCard(
                            title: "Days left",
                            value: "\(goal.daysRemaining)",
                            icon: "calendar",
                            color: .blue
                        )
                        
                        GoalStatCard(
                            title: "Monthly target",
                            value: "$\(formattedNumber(goal.requiredMonthlySavings))",
                            icon: "arrow.up.circle",
                            color: currentSavingsRate >= goal.requiredMonthlySavings ? .green : .red
                        )
                        
                        GoalStatCard(
                            title: "Status",
                            value: goal.isOnTrack ? "On track" : "Behind",
                            icon: goal.isOnTrack ? "checkmark.circle" : "exclamationmark.triangle",
                            color: goal.isOnTrack ? .green : .orange
                        )
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            newAmount = String(format: "%.0f", goal.currentAmount)
                            showingEditAmount = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Update Progress")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ColorTheme.primary)
                            .cornerRadius(12)
                        }
                        
                        if goal.progressPercentage >= 100 {
                            Button(action: {
                                markAsCompleted()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Completed")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .cornerRadius(12)
                            }
                        }
                        
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Goal")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Notes section
                    if let notes = goal.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTheme.primary)
                }
            }
        }
        .alert("Update Progress", isPresented: $showingEditAmount) {
            TextField("Current amount", text: $newAmount)
                .keyboardType(.decimalPad)
            
            Button("Cancel", role: .cancel) { }
            
            Button("Update") {
                updateAmount()
            }
        } message: {
            Text("Enter your current savings amount for this goal.")
        }
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }
    
    private func updateAmount() {
        let amount = Double(newAmount) ?? 0
        goal.currentAmount = amount
        
        if amount >= goal.targetAmount {
            goal.isCompleted = true
        }
        
        try? modelContext.save()
    }
    
    private func markAsCompleted() {
        goal.isCompleted = true
        goal.currentAmount = goal.targetAmount
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteGoal() {
        modelContext.delete(goal)
        try? modelContext.save()
        dismiss()
    }
    
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Goal Stat Card
private struct GoalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Updated ContentView.swift
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var values: [String: String] = [:]
    @State private var frequencies: [String: String] = [:]
    @State private var overallFrequency: String = "Annual"
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

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
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear
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

            ColorSchemeToggleButton()
                .padding(.top, 50)
                .padding(.trailing, 12)
        }
    }
}
