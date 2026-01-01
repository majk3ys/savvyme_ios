//
//  AuthService.swift
//  SavvyMe
//
//  Created by Melina Mackey on 23/12/2025.
//

import Firebase
import FirebaseAuth

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Configuration guard
    private func validateFirebaseConfiguration() throws {
        let apiKey = FirebaseApp.app()?.options.apiKey ?? ""
        if apiKey.contains("{{") || apiKey.isEmpty {
            throw NSError(
                domain: "AuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured. Replace API_KEY in GoogleService-Info.plist with the value from your Firebase project."]
            )
        }
    }

    // MARK: - Login
    func signIn(email: String, password: String) async throws {
        try validateFirebaseConfiguration()
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: - Register
    func register(email: String, password: String) async throws {
        try validateFirebaseConfiguration()
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    // MARK: - Logout
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Current user
    var currentUser: User? {
        Auth.auth().currentUser
    }
}
