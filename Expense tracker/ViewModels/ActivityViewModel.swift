//
//  ActivityViewModel.swift
//  Divvy
//

import Foundation
import SwiftUI

enum ActivityEventType {
    case expenseAdded
    case expenseUpdated
    case settlementMade
}

struct ActivityEvent: Identifiable {
    let id: String
    let type: ActivityEventType
    let groupId: String
    let groupName: String
    let groupEmoji: String
    let actorName: String
    let actorPhotoURL: String?
    let title: String
    let subtitle: String
    let amount: Double
    let currency: String
    let category: ExpenseCategory?
    let date: Date
}

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var events: [ActivityEvent] = []
    @Published var isLoading = false

    private let firestore = FirestoreService.shared
    private let auth = AuthService.shared

    func load() async {
        guard let userId = auth.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let groups = try await firestore.fetchGroups(for: userId)
            var allEvents: [ActivityEvent] = []

            for group in groups {
                // Fetch members for name resolution
                var members: [String: DivvyUser] = [:]
                for memberId in group.memberIds {
                    if let user = try? await firestore.fetchUser(id: memberId) {
                        members[memberId] = user
                    }
                }

                // Fetch expenses
                let expenses = (try? await firestore.fetchExpenses(groupId: group.id, limit: 30)) ?? []
                for expense in expenses {
                    let actor = members[expense.createdBy]
                    let paidByName = members[expense.paidBy]?.displayName ?? "Someone"
                    let splitCount = expense.splits.count

                    let subtitle: String
                    if expense.createdBy == expense.paidBy {
                        subtitle = "\(paidByName) paid · split \(splitCount) way\(splitCount == 1 ? "" : "s") · \(group.name)"
                    } else {
                        subtitle = "Paid by \(paidByName) · \(group.name)"
                    }

                    allEvents.append(ActivityEvent(
                        id: "expense-\(expense.id)",
                        type: .expenseAdded,
                        groupId: group.id,
                        groupName: group.name,
                        groupEmoji: group.emoji,
                        actorName: actor?.displayName ?? "Someone",
                        actorPhotoURL: actor?.photoURL,
                        title: expense.name,
                        subtitle: subtitle,
                        amount: expense.amount,
                        currency: expense.currency,
                        category: expense.category,
                        date: expense.createdAt
                    ))
                }

                // Fetch settlements
                let settlements = (try? await firestore.fetchSettlements(groupId: group.id)) ?? []
                for settlement in settlements {
                    let from = members[settlement.fromUserId]
                    let to = members[settlement.toUserId]
                    let fromName = from?.displayName ?? "Someone"
                    let toName = to?.displayName ?? "Someone"

                    allEvents.append(ActivityEvent(
                        id: "settlement-\(settlement.id)",
                        type: .settlementMade,
                        groupId: group.id,
                        groupName: group.name,
                        groupEmoji: group.emoji,
                        actorName: fromName,
                        actorPhotoURL: from?.photoURL,
                        title: "\(fromName) paid \(toName)",
                        subtitle: "Debt settled · \(group.name)",
                        amount: settlement.amount,
                        currency: settlement.currency,
                        category: nil,
                        date: settlement.settledAt
                    ))
                }
            }

            // Sort by most recent first
            events = allEvents.sorted { $0.date > $1.date }
        } catch {
            // silently fail — empty state shown
        }
    }
}
