//
//  NotificationManager.swift
//  SavvyMe
//
//  Created by Melina Mackey on 7/9/2025.
//

import SwiftUI
import UserNotifications

// MARK: - Notification Types
enum NotificationType {
    case logSpending
    case goalCheckpoint(goalId: UUID, checkpoint: Int) // e.g. 30-day, 7-day
    case goalRisk(goalId: UUID)
    case goalComplete(goalId: UUID)
    case goalMissed(goalId: UUID)
    case overspending(category: String)
    case positiveReinforcement(category: String)
}

// MARK: - Notification Manager
class NotificationManager : NSObject {
    static let shared = NotificationManager()
    private let notificationsEnabled = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: 1️⃣ Request Notification Permission
    func requestPermission() {
        guard notificationsEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            print("Notifications are currently disabled.")
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    // MARK: 2️⃣ Schedule a Notification
    private func scheduleNotification(title: String, body: String, triggerDate: Date, type: NotificationType) {
        let identifier = makeIdentifier(for: type)
        print("📅 Scheduling '\(title)' notification for \(triggerDate) [id: \(identifier)]")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let interval = triggerDate.timeIntervalSinceNow
        let trigger: UNNotificationTrigger
        
        if interval < 60 {
            let safeInterval = max(interval, 1) // must be >= 1s
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: safeInterval, repeats: false)
            print("⏳ Using UNTimeIntervalNotificationTrigger (\(safeInterval) seconds)")
        } else {
            trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate),
                repeats: false
            )
            print("📆 Using UNCalendarNotificationTrigger at \(triggerDate)")
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Remove existing with the same identifier → ensures one per rule
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            }
        }
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Pending notifications:", requests.map { "\($0.identifier): \($0.content.title)" })
        }
    }
    
    // MARK: Identifier Generator
    private func makeIdentifier(for type: NotificationType) -> String {
        switch type {
        case .logSpending:
            return "log_spending_reminder"
        case .goalCheckpoint(let goalId, let checkpoint):
            return "goal_checkpoint_\(goalId.uuidString)_\(checkpoint)"
        case .goalRisk(let goalId):
            return "goal_risk_\(goalId.uuidString)"
        case .goalComplete(let goalId):
            return "goal_complete_\(goalId.uuidString)"
        case .goalMissed(let goalId):
            return "goal_missed_\(goalId.uuidString)"
        case .overspending(let category):
            return "overspending_\(category)"
        case .positiveReinforcement(let category):
            return "positive_\(category)"
        }
    }
    
    // MARK: 3️⃣ Check All Rules
    func checkRules(transactions: [TransactionItem], goals: [Goal], budgets: [String: Double], benchmarks: [String: Double]) {
        guard notificationsEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        checkDataEntryReminder(transactions: transactions)
        checkOverspending(transactions: transactions, budgets: budgets, benchmarks: benchmarks)
        checkPositiveReinforcement(transactions: transactions, budgets: budgets, benchmarks: benchmarks)
        checkGoalProgress(goals: goals, transactions: transactions)
    }
    
    // MARK: Data Entry Reminder
    private func checkDataEntryReminder(transactions: [TransactionItem]) {
        let lastEntryDate = transactions.max(by: { $0.date ?? Date() < $1.date ?? Date() })?.date
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        if lastEntryDate == nil || lastEntryDate! < sevenDaysAgo {
            if let tomorrow10AM = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date().addingTimeInterval(86400)) {
                scheduleNotification(
                    title: "Log your spending",
                    body: "Haven’t logged this month’s spending yet? Quick 2 mins keeps you on track 👌",
                    triggerDate: tomorrow10AM,
                    type: .logSpending
                )
            }
        }
    }
    
    // MARK: Overspending Alerts
    private func checkOverspending(transactions: [TransactionItem], budgets: [String: Double], benchmarks: [String: Double]) {
        let categoryTotals = Dictionary(grouping: transactions, by: { $0.type }).mapValues {
            $0.reduce(0.0) { $0 + $1.amount }
        }
        
        for (category, total) in categoryTotals {
            if let budget = budgets[category], total > budget * 1.10 {
                scheduleNotification(
                    title: "Overspending alert",
                    body: "You’re over budget in \(category) this month. Consider adjusting your spending.",
                    triggerDate: Date().addingTimeInterval(5),
                    type: .overspending(category: category)
                )
            }
            if let benchmark = benchmarks[category], total > benchmark * 1.20 {
                scheduleNotification(
                    title: "Overspending alert",
                    body: "You’re spending 20% more than average households in \(category).",
                    triggerDate: Date().addingTimeInterval(5),
                    type: .overspending(category: category)
                )
            }
        }
    }
    
    // MARK: Positive Reinforcement
    private func checkPositiveReinforcement(transactions: [TransactionItem], budgets: [String: Double], benchmarks: [String: Double]) {
        let categoryTotals = Dictionary(grouping: transactions, by: { $0.type }).mapValues {
            $0.reduce(0.0) { $0 + $1.amount }
        }
        
        for (category, total) in categoryTotals {
            if let budget = budgets[category], total < budget * 0.90 {
                scheduleNotification(
                    title: "Well done!",
                    body: "You’re under budget in \(category). Keep it up! 🎉",
                    triggerDate: Date().addingTimeInterval(5),
                    type: .positiveReinforcement(category: category)
                )
            }
            if let benchmark = benchmarks[category], total < benchmark * 0.80 {
                scheduleNotification(
                    title: "Impressive!",
                    body: "You’re spending much less than average in \(category). Great work! 👏",
                    triggerDate: Date().addingTimeInterval(5),
                    type: .positiveReinforcement(category: category)
                )
            }
        }
    }
    
    // MARK: Calculate Current Savings Rate
    private func currentSavingsRate(from transactions: [TransactionItem]) -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let monthlyItems = transactions.filter { item in
            guard let date = item.date else { return false }
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            return month == currentMonth && year == currentYear
        }
        
        let monthlyIncome = monthlyItems.filter { ["salary","interest","investment","otherIncome"].contains($0.name) }
            .reduce(0) { $0 + $1.amount }
        
        let monthlySpending = monthlyItems.filter { AppCategories.spending.values.flatMap { $0 }.contains($0.name) }
            .reduce(0) { $0 + $1.amount }
        
        return monthlyIncome - monthlySpending
    }
    
    // MARK: Goal Progress
    private func checkGoalProgress(goals: [Goal], transactions: [TransactionItem]) {
        let savingsRate = currentSavingsRate(from: transactions)
        
        for goal in goals {
            let remainingDays = goal.daysRemaining
            let onTrack = goal.isOnTrack(currentSavingsRate: savingsRate)
            
            if (29...30).contains(remainingDays) {
                if onTrack {
                    scheduleNotification(
                        title: "Goal checkpoint",
                        body: "1 month to go and you’re on track to hit your \(goal.name) goal! 🎉",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalCheckpoint(goalId: goal.id, checkpoint: 30)
                    )
                } else {
                    scheduleNotification(
                        title: "Goal at risk",
                        body: "1 month left but you’re behind on your \(goal.name) goal. Adjust your spending to catch up!",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalRisk(goalId: goal.id)
                    )
                }
            }
            else if (6...7).contains(remainingDays) {
                if onTrack {
                    scheduleNotification(
                        title: "Goal alert",
                        body: "Only 7 days left—good news, you’re on track to reach your \(goal.name) goal! 🚀",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalCheckpoint(goalId: goal.id, checkpoint: 7)
                    )
                } else {
                    scheduleNotification(
                        title: "Goal at risk",
                        body: "7 days left but you’re behind on your \(goal.name) goal. Tighten up to give yourself the best shot!",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalRisk(goalId: goal.id)
                    )
                }
            }
            else if remainingDays == 0 {
                if onTrack {
                    scheduleNotification(
                        title: "Goal complete",
                        body: "Congratulations! You should've saved enough to hit your \(goal.name) goal on time 🎉. Close it off now.",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalComplete(goalId: goal.id)
                    )
                } else {
                    scheduleNotification(
                        title: "Goal missed",
                        body: "Today was the deadline for your \(goal.name) goal, but you didn’t quite make it. Review your spending!",
                        triggerDate: Date().addingTimeInterval(5),
                        type: .goalMissed(goalId: goal.id)
                    )
                }
            }
        }
    }
}

// MARK: - Delegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound]) // ✅ Show while app is open
    }
}
