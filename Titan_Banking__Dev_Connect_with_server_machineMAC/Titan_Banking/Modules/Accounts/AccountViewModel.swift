import Foundation
import Combine
import SwiftUI

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var accounts: [AccountModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    func loadAccounts(silent: Bool = false) async {
        if !silent { isLoading = true }
        errorMessage = nil
        defer { if !silent { isLoading = false } }
        do {
            let fresh = try await APIClient.shared.request(
                AccountEndpoint.getMyAccounts,
                responseType: [AccountModel].self
            )
            if fresh != self.accounts {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    self.accounts = fresh
                }
            }
            let accountNumbers = fresh.map { $0.accountNumber }
            SimulatorNotificationBridge.shared.startListening(forAccountNumbers: accountNumbers)
        } catch {
            if !silent { errorMessage = error.localizedDescription }
        }
    }

    func createAccount(type: String, currency: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            let newAccount = try await APIClient.shared.request(
                AccountEndpoint.createAccount(CreateAccountRequest(accountType: type, currency: currency)),
                responseType: AccountModel.self
            )
            accounts.append(newAccount)
            successMessage = "Account \(newAccount.accountNumber) created!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// GET /api/v1/accounts/{id}
    func fetchAccount(id: Int) async -> AccountModel? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let account = try await APIClient.shared.request(
                AccountEndpoint.getAccount(id),
                responseType: AccountModel.self
            )
            if let idx = accounts.firstIndex(where: { $0.id == id }) {
                accounts[idx] = account
            }
            return account
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
