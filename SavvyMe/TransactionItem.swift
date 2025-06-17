// TransactionItem.swift
import Foundation
import SwiftData

@Model
final class TransactionItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    var frequency: String
    var type: String

    init(id: UUID = UUID(), name: String, amount: Double, frequency: String, type: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.type = type
    }
}
