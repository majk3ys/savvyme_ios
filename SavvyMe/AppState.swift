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
                self.handleAuthChange(user: user)
            }
        }
    }
    
    private func handleAuthChange(user: User?) {
        guard let user else {
            isAuthenticated = false
            return
        }
        // Ensure a blank profile exists for new users so the Profile screen starts empty but is persisted.
        Task {
            await UserDataService.shared.saveBlankProfileIfNeeded()
        }
        isAuthenticated = true
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
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ColorTheme.primary.opacity(0.18),
                    ColorTheme.background,
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(ColorTheme.primary.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 2)
                .offset(x: -130, y: -350)

            Circle()
                .fill(ColorTheme.secondary.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 2)
                .offset(x: 140, y: -250)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(ColorTheme.primary.opacity(0.14))
                                .frame(width: 80, height: 80)

                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(ColorTheme.primary)
                        }

                        Text("Welcome to SavvyMe")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Take control of your spending with insights, goals, and a clear financial snapshot.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("name@email.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            SecureField("Enter your password", text: $password)
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                await login()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(ColorTheme.primary)
                            .cornerRadius(14)
                        }
                        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                        .opacity((isSubmitting || email.isEmpty || password.isEmpty) ? 0.75 : 1)

                        Button {
                            Task {
                                await register()
                            }
                        } label: {
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .foregroundColor(ColorTheme.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(ColorTheme.primary.opacity(0.55), lineWidth: 1.5)
                                )
                        }
                        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                        .opacity((isSubmitting || email.isEmpty || password.isEmpty) ? 0.75 : 1)
                    }
                    .padding(22)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 10)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
            }
        }
    }
    
    // MARK: - Actions
    private func login() async {
        guard !isSubmitting else { return }
        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
        }

        do {
            try await AuthService.shared.signIn(email: email, password: password)
            // ✅ AppState will auto-update via auth listener
        } catch {
            // logAuthError(error, context: "login")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isSubmitting = false
        }
    }

    private func register() async {
        guard !isSubmitting else { return }
        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
        }

        do {
            try await AuthService.shared.register(email: email, password: password)
        } catch {
            // logAuthError(error, context: "register")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isSubmitting = false
        }
    }
    
    // MARK: - Debug helpers
    // Use this to inspect FirebaseAuth errors in the console and to set a breakpoint.
    private func logAuthError(_ error: Error, context: String) {
        let nsError = error as NSError
        let code = nsError.code
        let domain = nsError.domain
        let message = nsError.localizedDescription
        print("❌ Auth \(context) error: domain=\(domain) code=\(code) message=\(message) userInfo=\(nsError.userInfo)")
    }
}
