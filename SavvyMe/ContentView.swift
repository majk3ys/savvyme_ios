//
//  ContentView.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import SwiftUI

struct MainTabView: View {
    init() {
        UITabBar.appearance().backgroundColor = UIColor(ColorTheme.nav)
        UITabBar.appearance().unselectedItemTintColor = UIColor(ColorTheme.text)
    }

    @State private var values: [String: String] = [:]
    @State private var frequencies: [String: String] = [:]
    @State private var overallFrequency: String = "Annual"

    var body: some View {
        TabView {
            SpendingInputView(
                overallFrequency: $overallFrequency
            )
                .tabItem {
                    Label("My finances", systemImage: "square.and.pencil")
                }

            DashboardView(
                overallFrequency: $overallFrequency
            )
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
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
    }
}

extension Color {
    static let categoryColors: [String: Color] = [
        "Home": .blue,
        "Daily living": .green,
        "Transport": .orange,
        "Entertainment & personal": .purple,
        "Income": .yellow
    ]

    static func shade(for category: String, index: Int, total: Int) -> Color {
        guard let base = categoryColors[category] else { return .gray }
        let fraction = Double(index) / Double(max(total - 1, 1))
        return base.opacity(0.5 + 0.5 * fraction) // Shades from 50% to 100%
    }
}
