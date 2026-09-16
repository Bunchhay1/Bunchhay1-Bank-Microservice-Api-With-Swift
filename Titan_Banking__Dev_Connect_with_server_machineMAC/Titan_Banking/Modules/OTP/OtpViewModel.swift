import Foundation
import Combine

@MainActor
final class OtpViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var message: String?
    @Published var otpCode: String?
    @Published var status: String?
    @Published var errorMessage: String?

    func generate() async {
        isLoading = true
        errorMessage = nil
        message = nil
        otpCode = nil
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                OtpEndpoint.generate,
                responseType: OtpGenerateResponse.self
            )
            if let err = resp.error {
                errorMessage = err
                return
            }
            message = resp.message
            status = resp.status
            otpCode = resp.otp
            InAppNotificationManager.shared.show(
                "OTP Sent",
                message: resp.message ?? "Check server console for the code",
                type: .success
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
