import Foundation
import Combine
import SwiftUI
import UserNotifications

enum TransactionMode {
    case transfer, deposit, withdraw
}

// Maximum transfer amount enforced on the client side.
// Must match RISK_HIGH_MAX_AMOUNT in titan-ai-service (default $100,000).
let kMaxTransferAmount: Double = 100_000

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var transactions: [TransactionResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadHistory(silent: Bool = false) async {
        if !silent { isLoading = true }
        errorMessage = nil
        defer { if !silent { isLoading = false } }
        do {
            let fresh = try await APIClient.shared.request(
                TransactionEndpoint.history,
                responseType: [TransactionResponse].self
            )
            if fresh != self.transactions {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    self.transactions = fresh
                }
            }
        } catch {
            if !silent { errorMessage = error.localizedDescription }
        }
    }

    func transfer(from: String, to: String, amount: Double, note: String, pin: String, currency: String = "USD") async -> Bool {
        if amount >= kMaxTransferAmount {
            let msg = "Transfer amount cannot exceed \(kMaxTransferAmount.formatted(.currency(code: currency))). This transaction is blocked."
            errorMessage = msg
            InAppNotificationManager.shared.show("Transfer Blocked 🚫", message: msg, type: .warning)
            return false
        }
        let cleanTo = to.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await execute(
            .transfer(TransactionRequest(
                fromAccountNumber: from,
                toAccountNumber: cleanTo,
                amount: amount,
                note: note.isEmpty ? "Transfer" : note,
                pin: pin
            )),
            action: "Transfer"
        )
        if ok {
            // ── Sender-side notification ──────────────────────────────────────
            // NOTE: Do NOT fire a push/banner here.
            // The backend publishes a Kafka event → titan-notifications-service
            // saves an IN_APP audit record → NotificationsViewModel polling
            // detects it and shows the banner + system push automatically.
            //
            // Firing a local notification here would create a duplicate because:
            //   1. TransactionViewModel fires immediately
            //   2. NotificationsViewModel poll fires ~5 s later from the backend record
            //
            // The only extra step for the sender on this device is the cross-simulator
            // Darwin broadcast so the RECEIVER's simulator gets an instant file-watcher push.
            SimulatorNotificationBridge.shared.broadcastTransfer(
                toAccountNumber: cleanTo,
                fromAccountNumber: from,
                amount: amount,
                currency: currency
            )
        }
        return ok
    }

    func deposit(to: String, amount: Double, pin: String) async -> Bool {
        let cleanTo = to.trimmingCharacters(in: .whitespacesAndNewlines)
        return await execute(
            .deposit(TransactionRequest(
                fromAccountNumber: nil,
                toAccountNumber: cleanTo,
                amount: amount,
                note: "Deposit",
                pin: pin
            )),
            action: "Deposit"
        )
        // NOTE: No local push here. The backend Kafka event →
        // notification service → polling → banner handles it.
    }

    func withdraw(from: String, amount: Double, pin: String) async -> Bool {
        let cleanFrom = from.trimmingCharacters(in: .whitespacesAndNewlines)
        return await execute(
            .withdraw(TransactionRequest(
                fromAccountNumber: cleanFrom,
                toAccountNumber: nil,
                amount: amount,
                note: "Withdrawal",
                pin: pin
            )),
            action: "Withdrawal"
        )
        // NOTE: No local push here. The backend Kafka event →
        // notification service → polling → banner handles it.
    }

    private func execute(_ endpoint: TransactionEndpoint, action: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            let tx = try await APIClient.shared.request(endpoint, responseType: TransactionResponse.self)

            if tx.status.uppercased() == "BLOCKED" {
                let msg = "🚫 Transaction blocked by Risk Engine. Amount too high or flagged as suspicious."
                errorMessage = msg
                InAppNotificationManager.shared.show("\(action) Blocked 🚫", message: msg, type: .failure)
                return false
            }

            successMessage = "\(action) successful. Ref: \(tx.referenceNumber ?? String(tx.id))"
            return true
        } catch {
            let msg = error.localizedDescription
            errorMessage = msg
            InAppNotificationManager.shared.show("\(action) Failed ❌", message: msg, type: .failure)
            return false
        }
    }
}
