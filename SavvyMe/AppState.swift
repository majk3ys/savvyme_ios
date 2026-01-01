//
//  AppState.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class AppState: ObservableObject {
    @Published var currentColorScheme: ColorScheme = .light
    @Published var hasUserToggledColorScheme: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var isSyncing: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?

   init() {
       listenToAuthChanges()
   }

    private func listenToAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.isAuthenticated = (user != nil)
                if let user { self.startSync(for: user) } else { self.stopSync() }
            }
        }
    }

    deinit {
        authListener.map(Auth.auth().removeStateDidChangeListener)
        stopSync()
    }

    private func startSync(for user: User) {
        profileListener?.remove()

        profileListener = Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .collection("private")
            .document("profile")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Profile listener error: \(error)")
                    return
                }
                guard let snapshot, snapshot.exists else { return }

                do {
                    let record = try snapshot.data(as: UserProfileRecord.self)
                    self.applyProfile(record)
                } catch {
                    print("Failed to decode profile: \(error)")
                }
            }
    }

    private func stopSync() {
        profileListener?.remove()
        profileListener = nil
    }

    private func applyProfile(_ record: UserProfileRecord) {
        UserDefaults.standard.set(record.age, forKey: "user_age")
        UserDefaults.standard.set(record.state, forKey: "user_state")
        UserDefaults.standard.set(record.postcode, forKey: "user_postcode")
        UserDefaults.standard.set(record.maritalStatus, forKey: "user_marital_status")
        UserDefaults.standard.set(record.adultsCount, forKey: "user_adults_count")
        UserDefaults.standard.set(record.childrenCount, forKey: "user_children_count")
        UserDefaults.standard.set(record.incomeRange, forKey: "user_income_range")
        UserDefaults.standard.set(record.lastUpdated.timeIntervalSince1970, forKey: "profile_last_updated")
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
