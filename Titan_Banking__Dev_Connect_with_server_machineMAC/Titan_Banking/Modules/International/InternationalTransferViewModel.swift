import Foundation
import Combine

@MainActor
final class InternationalTransferViewModel: ObservableObject {
    @Published var fromAccountNumber = ""
    @Published var amountText = ""
    @Published var swiftCode = ""
    @Published var iban = ""
    @Published var pin = ""
    @Published var note = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var accounts: [AccountModel] = []

    func submit() async -> Bool {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "Enter a valid amount."
            return false
        }
        let swift = swiftCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let ibanClean = iban.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")

        guard swift.range(of: #"^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$"#, options: .regularExpression) != nil else {
            errorMessage = "Invalid SWIFT code format."
            return false
        }
        guard ibanClean.range(of: #"^[A-Z]{2}\d{2}[A-Z0-9]{4,30}$"#, options: .regularExpression) != nil else {
            errorMessage = "Invalid IBAN format."
            return false
        }
        guard pin.count >= 4 else {
            errorMessage = "Enter your PIN."
            return false
        }
        guard !fromAccountNumber.isEmpty else {
            errorMessage = "Select a source account."
            return false
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let req = InternationalTransferRequest(
                fromAccountNumber: fromAccountNumber,
                amount: amount,
                pin: pin,
                note: note.isEmpty ? nil : note,
                swiftCode: swift,
                iban: ibanClean
            )
            let msg = try await APIClient.shared.requestPlainText(
                TransactionEndpoint.international(req)
            )
            successMessage = msg.isEmpty ? "International transfer initiated" : msg
            InAppNotificationManager.shared.show("SWIFT Transfer", message: successMessage ?? "OK", type: .success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
