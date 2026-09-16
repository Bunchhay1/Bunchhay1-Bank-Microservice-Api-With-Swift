import Foundation
import Combine          // ← required for ObservableObject + @Published
import UserNotifications
import UIKit

/// Manages APNs permission request and device token registration.
/// Flow:
///   1. App launches → requestPermission()
///   2. iOS grants permission → didRegisterForRemoteNotifications fires → token sent to backend
///   3. Backend stores token linked to logged-in user
///   4. After any transaction, backend calls APNs → phone shows alert even when app is closed
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {

    static let shared = PushNotificationManager()

    @Published var permissionGranted = false
    @Published var deviceToken: String?

    private override init() {}

    // ── Step 1: Ask user for permission ──────────────────────────────────────
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            // ← Avoid capturing `self` in a concurrent closure (Swift 6 rule).
            //   Instead, hop back to MainActor explicitly and reference `shared`.
            Task { @MainActor in
                PushNotificationManager.shared.permissionGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                if let error {
                    print("❌ Push permission error: \(error.localizedDescription)")
                }
            }
        }
    }

    // ── Step 2: Called by AppDelegate when iOS gives us the device token ─────
    func handleDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        print("📲 APNs device token: \(token)")

        // Send token to backend so it can push to this device
        Task {
            await registerTokenWithBackend(token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
    }

    // ── Step 3: POST token to titan-core-banking ─────────────────────────────
    private func registerTokenWithBackend(_ token: String) async {
        guard TokenStorage.shared.token != nil else {
            // Not logged in yet — token will be re-sent after login
            print("⚠️ Not logged in, skipping token registration")
            return
        }
        do {
            try await APIClient.shared.registerDeviceToken(token)
            print("✅ Device token registered with backend")
        } catch {
            print("❌ Failed to register device token: \(error.localizedDescription)")
        }
    }

    // Call this after login so token is always fresh on the server
    func registerTokenAfterLogin() {
        guard let token = deviceToken else { return }
        Task {
            await registerTokenWithBackend(token)
        }
    }
}
