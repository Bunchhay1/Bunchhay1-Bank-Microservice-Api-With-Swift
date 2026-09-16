import Foundation
import SwiftUI
import Combine

/// Drives all QR-payment screens.
/// Every published property is mutated on the MainActor.
@MainActor
final class QrViewModel: ObservableObject {

    // ── State ─────────────────────────────────────────────────────────────────
    @Published var isLoading       = false
    @Published var errorMessage:   String?  = nil
    @Published var successMessage: String?  = nil

    /// Active QR record (populated after generateQr or payByQr)
    @Published var activeQr:    QrPaymentResponse? = nil
    /// Persistent account QR (one per account, does not expire)
    @Published var accountQr:   QrPaymentResponse? = nil
    @Published var accountQrLoading = false
    /// History for the "My QR Codes" list
    @Published var history:     [QrPaymentResponse] = []

    // ── Generate QR ───────────────────────────────────────────────────────────

    /// Creates a new QR code the user can show to receive payment.
    /// - Returns `true` on success; `false` on error (errorMessage will be set).
    @discardableResult
    func generateQr(
        payeeAccountNumber: String,
        amount: Double?,
        note: String?,
        ttlMinutes: Int? = 15
    ) async -> Bool {
        beginRequest()
        defer { isLoading = false }
        let req = GenerateQrRequest(
            payeeAccountNumber: payeeAccountNumber,
            amount: amount,
            note: note?.isEmpty == true ? nil : note,
            ttlMinutes: ttlMinutes
        )
        do {
            let qr = try await APIClient.shared.request(
                QrEndpoint.generate(req),
                responseType: QrPaymentResponse.self
            )
            activeQr = qr
            successMessage = "QR code generated! It expires in \(ttlMinutes ?? 15) minutes."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // ── Pay by QR ─────────────────────────────────────────────────────────────

    /// Submits a payment after the payer scanned the QR token.
    /// - Parameter qrCode:  the raw string decoded from the camera
    /// - Returns `true` on success.
    @discardableResult
    func payByQr(
        qrCode: String,
        payerAccountNumber: String,
        amount: Double?,
        pin: String
    ) async -> Bool {
        beginRequest()
        defer { isLoading = false }
        let req = PayByQrRequest(
            qrCode: qrCode,
            payerAccountNumber: payerAccountNumber,
            amount: amount,
            pin: pin
        )
        do {
            let qr = try await APIClient.shared.request(
                QrEndpoint.pay(req),
                responseType: QrPaymentResponse.self
            )
            activeQr = qr
            let amtStr = qr.amount.map {
                $0.formatted(.currency(code: qr.currency ?? "USD"))
            } ?? "payment"
            successMessage = "✅ \(amtStr) sent successfully!"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // ── Cancel QR ─────────────────────────────────────────────────────────────

    @discardableResult
    func cancelQr(qrCode: String) async -> Bool {
        beginRequest()
        defer { isLoading = false }
        do {
            let qr = try await APIClient.shared.request(
                QrEndpoint.cancel(qrCode),
                responseType: QrPaymentResponse.self
            )
            activeQr = qr
            history.removeAll { $0.qrCode == qrCode }
            successMessage = "QR code cancelled."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // ── History ───────────────────────────────────────────────────────────────

    func loadHistory(accountNumber: String) async {
        beginRequest()
        defer { isLoading = false }
        do {
            history = try await APIClient.shared.request(
                QrEndpoint.history(accountNumber),
                responseType: [QrPaymentResponse].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Account QR ────────────────────────────────────────────────────────────

    /// Fetches (or auto-creates) the persistent account QR for the given account number.
    /// Uses a dedicated loading flag so the main `isLoading` spinner is not affected.
    func loadAccountQr(accountNumber: String) async {
        accountQrLoading = true
        errorMessage = nil
        defer { accountQrLoading = false }
        do {
            accountQr = try await APIClient.shared.request(
                QrEndpoint.accountQr(accountNumber),
                responseType: QrPaymentResponse.self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-fetches the account QR, resetting any existing value first so the UI
    /// shows a spinner rather than a stale image.
    func refreshAccountQr(accountNumber: String) async {
        accountQr = nil
        await loadAccountQr(accountNumber: accountNumber)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// Resets transient state and marks loading as started.
    /// Call `defer { isLoading = false }` in the caller so the flag clears
    /// when the async function returns — whether it succeeds or throws.
    private func beginRequest() {
        isLoading      = true
        errorMessage   = nil
        successMessage = nil
    }

    /// Converts the server's base64-PNG string into a UIImage.
    func qrUIImage(from base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}
