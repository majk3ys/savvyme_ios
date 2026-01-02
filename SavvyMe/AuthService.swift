//
//  AuthService.swift
//  SavvyMe
//
//  Created by Melina Mackey on 23/12/2025.
//

import FirebaseAuth
import Foundation

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Login
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: - Register
    func register(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
        // Immediately create a blank profile entry for the new user
        await UserDataService.shared.saveBlankProfileIfNeeded()
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
