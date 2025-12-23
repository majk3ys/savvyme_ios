//
//  AppState.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import FirebaseAuth
import SwiftUI

class AppState: ObservableObject {
    @Published var currentColorScheme: ColorScheme = .light
    @Published var hasUserToggledColorScheme: Bool = false
    @Published var isAuthenticated: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?

   init() {
       listenToAuthChanges()
   }

    private func listenToAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.isAuthenticated = (user != nil)
            }
        }
    }
    
    func initializeColorScheme(systemColorScheme: ColorScheme) {
        // Only set to system default if user hasn't manually toggled
        if !hasUserToggledColorScheme {
            currentColorScheme = systemColorScheme
        }
    }
    
    func toggleColorScheme() {
        // Toggle to opposite of current setting
        currentColorScheme = currentColorScheme == .dark ? .light : .dark
        hasUserToggledColorScheme = true
        saveColorSchemePreference()
    }
    
    // Reset color scheme state when user logs out (call this in your logout method)
    func resetColorSchemeOnLogout() {
        hasUserToggledColorScheme = false
        // Don't reset currentColorScheme - let it be set by system on next login
    }
    
    // If you need to save/restore the color scheme preference:
    private let colorSchemeKey = "colorSchemeOverride"
    private let hasToggledKey = "hasUserToggledColorScheme"
    
    func saveColorSchemePreference() {
        UserDefaults.standard.set(currentColorScheme == .dark ? "dark" : "light", forKey: colorSchemeKey)
        UserDefaults.standard.set(hasUserToggledColorScheme, forKey: hasToggledKey)
    }
    
    func loadColorSchemePreference() {
        let saved = UserDefaults.standard.string(forKey: colorSchemeKey)
        hasUserToggledColorScheme = UserDefaults.standard.bool(forKey: hasToggledKey)
        
        if hasUserToggledColorScheme {
            switch saved {
            case "dark": currentColorScheme = .dark
            case "light": currentColorScheme = .light
            default: break
            }
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("SavvyMe Login")
                .font(.largeTitle)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Login") {
                Task {
                    await login()
                }
            }
            .foregroundColor(ColorTheme.primary)

            Button("Register") {
                Task {
                    await register()
                }
            }
            .foregroundColor(ColorTheme.primary)
        }
        .padding()
    }
    
    // MARK: - Actions
    private func login() async {
        do {
            try await AuthService.shared.signIn(email: email, password: password)
            errorMessage = nil
            // ✅ AppState will auto-update via auth listener
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func register() async {
        do {
            try await AuthService.shared.register(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
