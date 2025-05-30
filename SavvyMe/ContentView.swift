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
            SpendingIncomeTabsView(
                values: $values,
                frequencies: $frequencies,
                overallFrequency: $overallFrequency
            )
                .tabItem {
                    Label("My finances", systemImage: "square.and.pencil")
                }

            DashboardView(
                values: $values,
                frequencies: $frequencies,
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
