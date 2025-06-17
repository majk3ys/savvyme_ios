//
//  UserProfileView.swift
//  SavvyMe
//
//  Created by Melina Mackey on 30/5/2025.
//

import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [TransactionItem]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("User profile settings go here")
                
                Button("Clear all data") {
                    for item in allItems {
                        modelContext.delete(item)
                    }
                    try? modelContext.save()
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}
