//
//  ContentView.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var values: [String: String] = [:]
    @State private var frequencies: [String: String] = [:]
    @State private var overallFrequency: String = "Annual"

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            ColorSchemeToggleButton()
                .padding(.top, 50)
                .padding(.trailing, 12)
        }
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

// MARK: - Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
