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
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
                    //.preferredColorScheme(.light) // 👈 forces light mode
            } else {
                AuthenticationView()
                    .environmentObject(appState)
                    //.preferredColorScheme(.light) // 👈 forces light mode
            }
        }
        .modelContainer(for: TransactionItem.self) // 👈 Add this line
    }
}


struct ColorTheme {
    static let primary = Color("MainColor")
    static let secondary = Color("DarkColor")
    static let background = Color("BackgroundColor")
    static let text = Color("TextColor")
    static let nav = Color("NavColor")
}
