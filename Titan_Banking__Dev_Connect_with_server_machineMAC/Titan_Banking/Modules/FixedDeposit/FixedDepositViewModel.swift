import Foundation
import Combine

@MainActor
final class FixedDepositViewModel: ObservableObject {
    @Published var selectedAccountId: Int?
    @Published var amountText = ""
    @Published var termMonths = 6

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var created: FixedDepositModel?

    let termOptions = [3, 6, 12, 24]

    func submit() async -> Bool {
        guard let accountId = selectedAccountId else {
            errorMessage = "Select an account."
            return false
        }
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "Enter a valid amount."
            return false
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let req = FixedDepositCreateRequest(
                accountId: accountId,
                amount: amount,
                termMonths: termMonths
            )
            let fd = try await APIClient.shared.request(
                FixedDepositEndpoint.create(req),
                responseType: FixedDepositModel.self
            )
            created = fd
            successMessage = String(
                format: "FD #\(fd.id) · maturity %@",
                fd.maturityAmount.formatted(.currency(code: "USD"))
            )
            InAppNotificationManager.shared.show("Fixed Deposit", message: successMessage ?? "Created", type: .success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
