//
//  SavvyMeApp.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import SwiftUI
import SwiftData

@main
struct SavvyMeApp: App {
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                        .preferredColorScheme(appState.currentColorScheme)
                } else {
                    AuthenticationView()
                        // Login page uses system default (no override)
                }
            }
            .environmentObject(appState)
        }
        .modelContainer(for: TransactionItem.self)
    }
}

struct ColorTheme {
    static let primary = Color("MainColor")
    static let secondary = Color("DarkColor")
    static let background = Color("BackgroundColor")
    static let text = Color("TextColor")
    static let nav = Color("NavColor")
}

struct ColorSchemeToggleButton: View {
    @Environment(\.colorScheme) var systemColorScheme
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: {
            appState.toggleColorScheme()
        }) {
            Image(systemName: appState.currentColorScheme == .dark ? "sun.max.fill" : "moon.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(.primary)
                .padding(6)
                .background(Color(.systemGray5).opacity(0.8))
                .clipShape(Circle())
                .shadow(radius: 1)
        }
        .accessibilityLabel("Toggle light/dark mode")
        .onAppear {
            // Initialize with system setting when first shown after login
            appState.initializeColorScheme(systemColorScheme: systemColorScheme)
        }
    }
}
