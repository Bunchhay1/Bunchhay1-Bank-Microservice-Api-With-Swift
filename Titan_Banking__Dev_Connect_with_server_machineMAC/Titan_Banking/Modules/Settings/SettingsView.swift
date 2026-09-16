import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showLogoutAlert = false
    @State private var showNotifPrefs  = false
    @State private var showSecurity    = false
    @State private var showAbout       = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // ── Profile Card ──────────────────────────────────────────────
                profileCard

                // ── Account ───────────────────────────────────────────────────
                SettingsSection(title: "Account") {
                    SettingsNavRow(icon: "bell.badge.fill",    color: .orange,
                                   label: "Notifications",
                                   subtitle: "Manage push, SMS & email") {
                        // Navigate to notification preferences in NotificationsView
                        showNotifPrefs = true
                    }
                    Divider().padding(.leading, 52)
                    SettingsNavRow(icon: "lock.shield.fill",   color: Color.titanPrimary,
                                   label: "Security & PIN",
                                   subtitle: "Change PIN, biometrics") {
                        showSecurity = true
                    }
                    Divider().padding(.leading, 52)
                    SettingsNavRow(icon: "creditcard.fill",    color: .teal,
                                   label: "Linked Accounts",
                                   subtitle: "\(authVM.userProfile != nil ? "Manage accounts" : "—")") {}
                }

                // ── Preferences ───────────────────────────────────────────────
                SettingsSection(title: "Preferences") {
                    SettingsNavRow(icon: "globe",              color: Color(red:0.10,green:0.55,blue:0.85),
                                   label: "Language",
                                   subtitle: "English / ខ្មែរ") {}
                    Divider().padding(.leading, 52)
                    SettingsNavRow(icon: "moon.stars.fill",    color: .indigo,
                                   label: "Appearance",
                                   subtitle: "Light, Dark, System") {}
                }

                // ── Support ───────────────────────────────────────────────────
                SettingsSection(title: "Support") {
                    SettingsNavRow(icon: "questionmark.bubble.fill", color: .cyan,
                                   label: "Help & FAQ",
                                   subtitle: "Common questions") {}
                    Divider().padding(.leading, 52)
                    SettingsNavRow(icon: "envelope.fill",      color: .green,
                                   label: "Contact Us",
                                   subtitle: "support@titan-banking.com") {}
                    Divider().padding(.leading, 52)
                    SettingsNavRow(icon: "doc.text.fill",      color: .gray,
                                   label: "Terms & Privacy",
                                   subtitle: "Legal documents") {
                        showAbout = true
                    }
                }

                // ── App info ──────────────────────────────────────────────────
                SettingsSection(title: "") {
                    SettingsInfoRow(label: "Version", value: "1.0.0 (Build 1)")
                    Divider().padding(.leading, 16)
                    SettingsInfoRow(label: "Environment", value: "Docker Local")
                }

                // ── Logout ────────────────────────────────────────────────────
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 20)
            }
            .padding(.top, 16)
        }
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Log Out", role: .destructive) { authVM.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again.")
        }
        // Notification preferences sheet
        .sheet(isPresented: $showNotifPrefs) {
            NavigationStack {
                NotificationsView(vm: NotificationsViewModel())
                    .environmentObject(authVM)
            }
        }
        // Security (placeholder — needs backend PIN change API)
        .sheet(isPresented: $showSecurity) {
            SecurityPlaceholderView()
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.titanPrimary, Color.titanPrimary.opacity(0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Text(initials)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(fullName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.titanDark)
                Text(authVM.userProfile?.email ?? "@\(authVM.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.titanSecondary)

                // Tier badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("Verified Member")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.titanPrimary)
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    private var fullName: String {
        let name = authVM.userProfile?.fullName ?? ""
        return name.isEmpty ? authVM.username : name
    }

    private var initials: String {
        guard let p = authVM.userProfile else {
            return String(authVM.username.prefix(1)).uppercased()
        }
        let f = String((p.firstName ?? "").prefix(1))
        let l = String((p.lastName ?? "").prefix(1))
        return (f + l).uppercased()
    }
}

// MARK: - Reusable Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.titanSecondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Navigation Row

struct SettingsNavRow: View {
    let icon: String
    let color: Color
    let label: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Labels
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.titanDark)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.titanSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.titanSecondary.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Row (no chevron)

struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.titanDark)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color.titanSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Security & OTP

struct SecurityPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOTP = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showOTP = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(Color.titanPrimary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generate OTP")
                                    .foregroundStyle(Color.titanDark)
                                Text("POST /api/auth/otp/generate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("PIN change and biometric settings are not exposed by the backend yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Security & PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showOTP) {
                OtpGenerateView()
            }
        }
    }
}
