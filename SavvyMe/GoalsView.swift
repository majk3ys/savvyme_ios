// GoalsView.swift
import Foundation
import SwiftData
import SwiftUI

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.deadline) private var goals: [Goal]
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
        // Calculate current monthly savings based on the actual current month
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let monthlyItems = allItems.filter { item in
            guard let itemDate = item.date else { return false }
            let itemMonth = calendar.component(.month, from: itemDate)
            let itemYear = calendar.component(.year, from: itemDate)
            return itemMonth == currentMonth && itemYear == currentYear
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
                GoalsFilterPicker(goals: goals, selectedFilter: $selectedFilter)
                
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
                    Text("Total progress")
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
                    Text("Monthly target")
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
                        Text("Overall progress")
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
    let goals: [Goal]
    @Binding var selectedFilter: String
    
    private var filterOptions: [String] {
        let activeGoals = goals.filter { !$0.isCompleted }
        let categoriesWithGoals = Set(activeGoals.map { $0.category })
        let availableCategories = GoalCategories.categories.filter { categoriesWithGoals.contains($0) }
        return ["All"] + availableCategories
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
                            Image(systemName: goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? "checkmark.circle.fill" : "clock.fill")
                                .font(.caption)
                                .foregroundColor(goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? .green : .red)
                            
                            Text(goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? "On track" : "Behind schedule")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? .green : .red)
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

// MARK: - Edit Goal View
struct EditGoalView: View {
    let goal: Goal
    let onSave: (Goal) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var targetAmount: String
    @State private var currentAmount: String
    @State private var selectedCategory: String
    @State private var deadline: Date
    @State private var notes: String
    
    init(goal: Goal, onSave: @escaping (Goal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        
        // Initialize state with current goal values
        _name = State(initialValue: goal.name)
        _targetAmount = State(initialValue: String(format: "%.0f", goal.targetAmount))
        _currentAmount = State(initialValue: String(format: "%.0f", goal.currentAmount))
        _selectedCategory = State(initialValue: goal.category)
        _deadline = State(initialValue: goal.deadline)
        _notes = State(initialValue: goal.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal name")
                            .font(.headline)
                        
                        TextField("e.g., Europe trip, first home deposit", text: $name)
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
                        Text("Target amount")
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
                        Text("Current amount saved")
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
                        Text("Target date")
                            .font(.headline)
                        
                        DatePicker("Deadline", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.headline)
                        
                        TextField("Add any notes about this goal...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Edit goal")
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
        
        let updatedGoal = Goal(
            name: name,
            targetAmount: target,
            currentAmount: current,
            category: selectedCategory,
            deadline: deadline,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(updatedGoal)
        dismiss()
    }
}

// MARK: - Add Goal View
struct AddGoalView: View {
    let onSave: (Goal) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var selectedCategory = "Holiday/recreation"
    @State private var deadline = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal name")
                            .font(.headline)
                        
                        TextField("e.g., Europe trip, first home deposit", text: $name)
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
                        Text("Target amount")
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
                        Text("Current amount saved (optional)")
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
                        Text("Target date")
                            .font(.headline)
                        
                        DatePicker("Deadline", selection: $deadline, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.headline)
                        
                        TextField("Add any notes about this goal...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("New goal")
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
    
    @State private var showingEditGoal = false
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
                            value: goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? "On track" : "Behind",
                            icon: goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? "checkmark.circle" : "exclamationmark.triangle",
                            color: goal.isOnTrack(currentSavingsRate: currentSavingsRate) ? .green : .red
                        )
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingEditGoal = true
                        }) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                Text("Edit progress")
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
                                    Text("Mark as completed")
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
                                Text("Delete goal")
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
            .navigationTitle("Goal details")
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
        .sheet(isPresented: $showingEditGoal) {
            EditGoalView(goal: goal) { updatedGoal in
                // Update the existing goal with new values
                goal.name = updatedGoal.name
                goal.targetAmount = updatedGoal.targetAmount
                goal.currentAmount = updatedGoal.currentAmount
                goal.category = updatedGoal.category
                goal.deadline = updatedGoal.deadline
                goal.notes = updatedGoal.notes
                
                // Check if goal should be marked complete
                if updatedGoal.currentAmount >= updatedGoal.targetAmount {
                    goal.isCompleted = true
                }
                
                try? modelContext.save()
            }
        }
        .alert("Delete goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
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
