import Foundation
import Combine

@MainActor
final class ScheduledTransferViewModel: ObservableObject {
    @Published var fromAccountNumber = ""
    @Published var toAccountNumber = ""
    @Published var amountText = ""
    @Published var pin = ""
    @Published var note = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var created: ScheduledTransactionModel?

    func submit() async -> Bool {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "Enter a valid amount."
            return false
        }
        guard !fromAccountNumber.isEmpty, !toAccountNumber.isEmpty else {
            errorMessage = "From and to accounts are required."
            return false
        }
        guard pin.count >= 4 else {
            errorMessage = "Enter your PIN."
            return false
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let req = TransactionRequest(
                fromAccountNumber: fromAccountNumber,
                toAccountNumber: toAccountNumber.trimmingCharacters(in: .whitespaces),
                amount: amount,
                note: note.isEmpty ? "Scheduled payment" : note,
                pin: pin
            )
            let result = try await APIClient.shared.request(
                ScheduledTransactionEndpoint.create(req),
                responseType: ScheduledTransactionModel.self
            )
            created = result
            successMessage = "Scheduled #\(result.id) · \(result.status ?? "PENDING")"
            InAppNotificationManager.shared.show("Scheduled", message: successMessage ?? "OK", type: .success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
