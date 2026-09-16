import Foundation
import Combine
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = TokenStorage.shared.isLoggedIn
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile?

    // fallback display name before profile loads
    var username: String { userProfile?.username ?? "" }

    init() {
        // On app relaunch with a saved token, restore profile + restart file-watcher
        if TokenStorage.shared.isLoggedIn,
           let uid = UserDefaults.standard.object(forKey: "titan_user_id") as? Int {
            Task {
                await fetchProfile(id: uid)
                PushNotificationManager.shared.registerTokenAfterLogin()
                await startBridgeListening()   // ← restart file-watcher for all accounts
            }
        }

        // Re-register device token whenever the app comes back to the foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isLoggedIn else { return }
            Task { @MainActor in
                PushNotificationManager.shared.registerTokenAfterLogin()
                await self.startBridgeListening()  // ← also restart on foreground
            }
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await APIClient.shared.request(
                AuthEndpoint.login(LoginRequest(username: username, password: password)),
                responseType: AuthResponse.self
            )
            TokenStorage.shared.token = resp.token
            UserDefaults.standard.set(resp.id, forKey: "titan_user_id")
            isLoggedIn = true
            await fetchProfile(id: resp.id)
            PushNotificationManager.shared.registerTokenAfterLogin()
            await startBridgeListening()   // ← start file-watcher immediately after login
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(username: String, password: String, email: String, firstName: String, lastName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let req = RegisterRequest(
                firstName: firstName, lastName: lastName,
                username: username, email: email,
                password: password, pin: "0000"
            )
            let resp = try await APIClient.shared.request(
                AuthEndpoint.register(req),
                responseType: AuthResponse.self
            )
            TokenStorage.shared.token = resp.token
            UserDefaults.standard.set(resp.id, forKey: "titan_user_id")
            isLoggedIn = true
            await fetchProfile(id: resp.id)
            PushNotificationManager.shared.registerTokenAfterLogin()
            await startBridgeListening()   // ← start file-watcher after register too
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchProfile(id: Int) async {
        do {
            userProfile = try await APIClient.shared.request(
                UserEndpoint.getUser(id),
                responseType: UserProfile.self
            )
        } catch {
            // non-fatal — dashboard still works without profile
        }
    }

    func logout() {
        SimulatorNotificationBridge.shared.stopListening()  // ← stop watching on logout
        TokenStorage.shared.token = nil
        UserDefaults.standard.removeObject(forKey: "titan_user_id")
        userProfile = nil
        isLoggedIn = false
    }

    // ── Fetch the logged-in user's accounts and register all account numbers
    //    with the file-watcher bridge. This must run right after login so the
    //    receiver simulator is always watching, even if the user never opens
    //    the Accounts tab.
    private func startBridgeListening() async {
        do {
            let accounts = try await APIClient.shared.request(
                AccountEndpoint.getMyAccounts,
                responseType: [AccountModel].self
            )
            let numbers = accounts.map { $0.accountNumber }
            SimulatorNotificationBridge.shared.startListening(forAccountNumbers: numbers)
        } catch {
            // Non-fatal — file-watcher path is a simulator convenience only.
            // The polling path (NotificationsViewModel) still works regardless.
            print("⚠️ [Auth] Could not start bridge listening: \(error.localizedDescription)")
        }
    }
}
