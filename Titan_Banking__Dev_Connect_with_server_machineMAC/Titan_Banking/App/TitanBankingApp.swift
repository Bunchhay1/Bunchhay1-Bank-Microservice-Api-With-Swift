import SwiftUI

// MARK: - RootView — auth gate

struct RootView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        if authVM.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @ObservedObject private var inAppNotif = InAppNotificationManager.shared
    @EnvironmentObject private var authVM: AuthViewModel

    // Single shared NotificationsViewModel — one polling loop, one lastSeenCount.
    @StateObject private var globalNotifVM = NotificationsViewModel()

    // Tab index — shared so DashboardView can programmatically switch to Notifications.
    @State private var selectedTab: Int = 0

    // Tab indices
    private let tabHome          = 0
    private let tabAccounts      = 1
    private let tabTransactions  = 2
    private let tabLoans         = 3
    private let tabNotifications = 4
    private let tabSettings      = 5

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Home ──────────────────────────────────────────────────────────
            NavigationStack {
                DashboardView(onNotificationBellTapped: {
                    selectedTab = tabNotifications
                })
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(tabHome)

            // ── Accounts ──────────────────────────────────────────────────────
            NavigationStack { AccountsView() }
                .tabItem { Label("Accounts", systemImage: "creditcard.fill") }
                .tag(tabAccounts)

            // ── Transactions ──────────────────────────────────────────────────
            NavigationStack { TransactionsView() }
                .tabItem { Label("Transfers", systemImage: "arrow.left.arrow.right.circle.fill") }
                .tag(tabTransactions)

            // ── Loans ─────────────────────────────────────────────────────────
            NavigationStack { LoansView() }
                .tabItem { Label("Loans", systemImage: "doc.text.fill") }
                .tag(tabLoans)

            // ── Notifications ─────────────────────────────────────────────────
            // Renamed from "Alerts" → "Notifications"
            // Shared vm prevents a second polling loop being created inside the view.
            NavigationStack {
                NotificationsView(vm: globalNotifVM)
            }
            .tabItem { Label("Notifications", systemImage: "bell.fill") }
            .tag(tabNotifications)
            .badge(inAppNotif.unreadCount > 0 ? inAppNotif.unreadCount : 0)

            // ── Settings ──────────────────────────────────────────────────────
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(tabSettings)
        }
        .tint(.blue)
        // ── Start polling as soon as the tab bar appears ───────────────────────
        // .task runs immediately on appear — covers the case where the user was
        // already logged in (username already set) so onChange never fires.
        .task {
            // Wait briefly for fetchProfile to complete if it's still in-flight
            if authVM.username.isEmpty {
                // Poll until username arrives (max ~3 s)
                for _ in 0..<6 {
                    try? await Task.sleep(for: .milliseconds(500))
                    if !authVM.username.isEmpty { break }
                }
            }
            guard !authVM.username.isEmpty else { return }
            globalNotifVM.resetAndStartPolling(accountId: authVM.username)
        }
        // Also handles mid-session username changes (e.g. after re-login)
        .onChange(of: authVM.username) { _, newUsername in
            guard !newUsername.isEmpty else { return }
            globalNotifVM.resetAndStartPolling(accountId: newUsername)
        }
        .onDisappear {
            globalNotifVM.stopPolling()
        }
    }
}
