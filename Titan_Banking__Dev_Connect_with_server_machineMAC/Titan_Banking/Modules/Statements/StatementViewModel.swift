import Foundation
import Combine

@MainActor
final class StatementViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pdfData: Data?
    @Published var successMessage: String?

    func download(accountId: Int) async {
        isLoading = true
        errorMessage = nil
        pdfData = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.requestData(StatementEndpoint.pdf(accountId))
            pdfData = data
            successMessage = "Statement downloaded (\(data.count) bytes)"
            InAppNotificationManager.shared.show(
                "Statement ready",
                message: "Account #\(accountId) PDF downloaded",
                type: .success
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
