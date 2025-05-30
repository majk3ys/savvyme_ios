//
//  AppState.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//


import SwiftUI

class AppState: ObservableObject {
    @Published var isAuthenticated = false
}

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("SavvyMe Login")
                .font(.largeTitle)

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Login") {
                // Call your backend here
                // For now, we simulate successful login
                appState.isAuthenticated = true
            }

            Button("Register") {
                // Navigate to register screen (optional)
            }
        }
        .padding()
    }
}
