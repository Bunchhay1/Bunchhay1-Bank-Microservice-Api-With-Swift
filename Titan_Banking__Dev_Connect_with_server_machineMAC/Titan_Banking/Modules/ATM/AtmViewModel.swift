import Foundation
import Combine
import SwiftUI

// MARK: - Exchange Rate
// 1 USD = 4,100 KHR  (replace with a live FX call when available)
let KHR_PER_USD: Double = 4100

@MainActor
final class AtmViewModel: ObservableObject {

    // ── State ──────────────────────────────────────────────────────────────
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var successCode: AtmCodeResponse?   // result after generate
    @Published var codeStatus:  AtmCodeResponse?   // result after status check
    @Published var cancelled    = false

    // ── Currency toggle ────────────────────────────────────────────────────
    /// Drives the currency picker in the UI: true = USD, false = KHR
    @Published var isUSD = true

    // ── Computed helpers ───────────────────────────────────────────────────

    /// Amount displayed in the currently selected currency
    func displayAmount(usdAmount: Double) -> String {
        if isUSD {
            return String(format: "$%.2f", usdAmount)
        } else {
            let khr = usdAmount * KHR_PER_USD
            return String(format: "%.0f ៛", khr)
        }
    }

    /// Convert UI-entered value to USD (what the backend always stores)
    func toUSD(_ value: Double) -> Double {
        isUSD ? value : value / KHR_PER_USD
    }

    /// Convert USD to display value for the selected currency
    func fromUSD(_ usd: Double) -> Double {
        isUSD ? usd : usd * KHR_PER_USD
    }

    // ── Countdown helper ───────────────────────────────────────────────────
    func minutesRemaining(from expiresAt: Date?) -> Int {
        guard let exp = expiresAt else { return 0 }
        return max(0, Int(exp.timeIntervalSinceNow / 60))
    }

    func secondsRemaining(from expiresAt: Date?) -> Int {
        guard let exp = expiresAt else { return 0 }
        return max(0, Int(exp.timeIntervalSinceNow))
    }

    // ── 1. GENERATE ────────────────────────────────────────────────────────
    /// Ask the backend to generate a 12-digit ATM withdrawal code.
    /// `amount` is always in USD (converted before calling).
    func generateCode(accountNumber: String, amountUSD: Double, pin: String) async {
        isLoading    = true
        errorMessage = nil
        successCode  = nil

        let req = AtmGenerateRequest(
            accountNumber: accountNumber,
            amount: amountUSD,
            pin: pin
        )

        do {
            let result = try await APIClient.shared.request(
                AtmEndpoint.generate(req),
                responseType: AtmCodeResponse.self
            )
            successCode = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // ── 2. CANCEL ─────────────────────────────────────────────────────────
    func cancelCode(_ code: String) async {
        isLoading    = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.request(
                AtmEndpoint.cancel(code),
                responseType: AtmCodeResponse.self
            )
            cancelled   = true
            successCode = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // ── 3. STATUS REFRESH ─────────────────────────────────────────────────
    func refreshStatus(_ code: String) async {
        do {
            let result = try await APIClient.shared.request(
                AtmEndpoint.status(code),
                responseType: AtmCodeResponse.self
            )
            // Update successCode so the UI reacts (e.g. show USED state)
            successCode = result
        } catch {
            // Status refresh is non-critical — swallow silently
        }
    }

    // ── 4. REDEEM (ATM terminal simulator) ─────────────────────────────
    @Published var redeemResult: AtmCodeResponse?
    @Published var redeemCode = ""
    @Published var redeemTerminalId = "ATM-PP-001"

    func redeemCode() async {
        let code = redeemCode.trimmingCharacters(in: .whitespaces)
        guard code.count == 12 else {
            errorMessage = "Enter the full 12-digit ATM code."
            return
        }
        isLoading = true
        errorMessage = nil
        redeemResult = nil
        defer { isLoading = false }

        let terminal = redeemTerminalId.trimmingCharacters(in: .whitespaces)
        let req = AtmRedeemRequest(
            code: code,
            terminalId: terminal.isEmpty ? nil : terminal
        )
        do {
            let result = try await APIClient.shared.request(
                AtmEndpoint.redeem(req),
                responseType: AtmCodeResponse.self
            )
            redeemResult = result
            successCode = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        successCode  = nil
        codeStatus   = nil
        errorMessage = nil
        cancelled    = false
        isLoading    = false
        redeemResult = nil
    }
}
