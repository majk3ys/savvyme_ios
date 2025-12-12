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
        return min(remainingAmount / months, remainingAmount)
    }
    
    func isOnTrack(currentSavingsRate: Double) -> Bool {
      return currentSavingsRate >= requiredMonthlySavings
  }
}

// MARK: - Goal Categories
struct GoalCategories {
    static let categories = [
        "Holiday/recreation",
        "House deposit",
        "Car purchase",
        "Education",
        "Wedding",
        "Investment",
        "Retirement",
        "Other"
    ]
    
    static let categoryIcons: [String: String] = [
        "Holiday/recreation": "airplane",
        "House deposit": "house.fill",
        "Car purchase": "car.fill",
        "Education": "graduationcap.fill",
        "Wedding": "heart.fill",
        "Investment": "chart.line.uptrend.xyaxis",
        "Retirement": "figure.walk",
        "Other": "star.fill"
    ]
    
    static let categoryColors: [String: Color] = [
        "Holiday/recreation": .orange,
        "House deposit": .blue,
        "Car purchase": .gray,
        "Education": .purple,
        "Wedding": .pink,
        "Investment": .mint,
        "Retirement": .indigo,
        "Other": .yellow
    ]
}
