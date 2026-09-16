import SwiftUI

// MARK: - NotificationsView

struct NotificationsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var vm: NotificationsViewModel
    @State private var selectedTab = 0
    @State private var auditUsername = ""
    @State private var auditTransactionId = ""

    private var accountId: String {
        authVM.username.isEmpty ? "me" : authVM.username
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Segment Control ───────────────────────────────────────────────
            Picker("", selection: $selectedTab) {
                Text("Activity").tag(0)
                Text("Preferences").tag(1)
                Text("Audit").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            Divider()

            if selectedTab == 0 {
                historyTab
            } else if selectedTab == 1 {
                preferencesTab
            } else {
                auditLookupTab
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if vm.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.markAllRead()
                    } label: {
                        Text("Mark all read")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .task {
            await vm.fetchPreference(userId: accountId)
        }
        .refreshable {
            await vm.fetchHistory(accountId: accountId)
        }
        .onAppear {
            if auditUsername.isEmpty {
                auditUsername = accountId
            }
        }
    }

    // MARK: - Audit lookup tab (by user / transaction)

    private var auditLookupTab: some View {
        Form {
            Section {
                Text("Query titan-notifications AuditController directly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("By username") {
                TextField("Username", text: $auditUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("GET /api/audit/user/{username}") {
                    Task {
                        await vm.fetchAuditByUser(auditUsername.trimmingCharacters(in: .whitespaces))
                        selectedTab = 0
                    }
                }
            }

            Section("By transaction ID") {
                TextField("Transaction ID", text: $auditTransactionId)
                    .keyboardType(.numbersAndPunctuation)
                Button("GET /api/audit/transaction/{id}") {
                    Task {
                        await vm.fetchAuditByTransaction(
                            auditTransactionId.trimmingCharacters(in: .whitespaces)
                        )
                        selectedTab = 0
                    }
                }
            }

            Section("By account (default Activity)") {
                Button("Reload account audit") {
                    Task {
                        await vm.fetchHistory(accountId: accountId)
                        selectedTab = 0
                    }
                }
            }

            if let err = vm.errorMessage {
                Section {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - History Tab

    @ViewBuilder
    private var historyTab: some View {
        if vm.isLoading && vm.records.isEmpty {
            loadingView
        } else if let err = vm.errorMessage, vm.records.isEmpty {
            errorView(err)
        } else if vm.records.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    // ── New notifications banner ──────────────────────────
                    if vm.unreadCount > 0 {
                        unreadBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }

                    // ── Group by date ──────────────────────────────────────
                    ForEach(groupedRecords, id: \.0) { section, records in
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header
                            Text(section)
                                .font(.footnote.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 8)

                            // Cards
                            VStack(spacing: 1) {
                                ForEach(Array(records.enumerated()), id: \.element.id) { idx, record in
                                    NotificationCardView(record: record, vm: vm)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .clipShape(
                                            RoundedCorner(
                                                radius: 14,
                                                corners: corners(idx: idx, total: records.count)
                                            )
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // Group records by "Today", "Yesterday", or date string
    private var groupedRecords: [(String, [NotificationAuditRecord])] {
        var groups: [(String, [NotificationAuditRecord])] = []
        var seen: [String: Int] = [:]
        for record in vm.records {
            let label = sectionLabel(from: record.attemptedAt)
            if let idx = seen[label] {
                groups[idx].1.append(record)
            } else {
                seen[label] = groups.count
                groups.append((label, [record]))
            }
        }
        return groups
    }

    private func sectionLabel(from raw: String) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = fmt.date(from: raw) else { return "Earlier" }
        if Calendar.current.isDateInToday(date)     { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let out = DateFormatter()
        out.dateFormat = "MMMM d, yyyy"
        return out.string(from: date)
    }

    private func corners(idx: Int, total: Int) -> UIRectCorner {
        if total == 1 { return .allCorners }
        if idx == 0   { return [.topLeft, .topRight] }
        if idx == total - 1 { return [.bottomLeft, .bottomRight] }
        return []
    }

    // MARK: - Unread Banner

    private var unreadBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(vm.unreadCount) new \(vm.unreadCount == 1 ? "notification" : "notifications")")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Tap 'Mark all read' to dismiss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Empty / Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
            Text("Loading notifications…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
            }
            Text("No Activity Yet")
                .font(.title3.bold())
            Text("Transaction alerts and transfer\nnotifications will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Could Not Load")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                Task { await vm.fetchHistory(accountId: accountId) }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Preferences Tab

    @ViewBuilder
    private var preferencesTab: some View {
        PreferencesFormView(
            pref: vm.preference ?? NotificationPreference(
                userId: accountId,
                emailEnabled: true,
                smsEnabled: false,
                pushEnabled: true,
                marketingEnabled: false,
                locale: "en"
            ),
            vm: vm,
            userId: accountId
        )
    }
}

// MARK: - Notification Card

struct NotificationCardView: View {
    let record: NotificationAuditRecord
    let vm: NotificationsViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {

            // ── Icon ──────────────────────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 46, height: 46)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // ── Content ───────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                // Title row — shows smart transaction title + date (NO channel name label)
                HStack(alignment: .firstTextBaseline) {
                    Text(titleText)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(vm.formatDate(record.attemptedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Message body — clean, pre-formatted by backend
                Text(cleanMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Footer: status badge + amount
                HStack(spacing: 6) {
                    StatusPill(status: record.status)
                    if let amt = extractedAmount {
                        Text(amt)
                            .font(.caption.bold())
                            .foregroundStyle(isReceived ? .green : .primary)
                    }
                    Spacer()
                    if record.urgent {
                        Label("Urgent", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// True when this is a money-received notification (Account B's perspective)
    private var isReceived: Bool {
        record.message.lowercased().hasPrefix("you received")
    }

    /// True when this is a transfer-sent notification (Account A's perspective)
    private var isSent: Bool {
        record.message.lowercased().hasPrefix("you transferred")
    }

    private var isDeposit: Bool {
        record.message.lowercased().hasPrefix("deposit")
    }

    private var isWithdrawal: Bool {
        record.message.lowercased().hasPrefix("withdrawal")
    }

    /// Smart title derived from message content — no raw channel name shown.
    private var titleText: String {
        if isReceived   { return "Money Received" }
        if isSent       { return "Transaction Complete" }
        if isDeposit    { return "Deposit Confirmed" }
        if isWithdrawal { return "Withdrawal Confirmed" }
        return "Transaction Update"
    }

    /// Return the message as-is — the backend now sends clean, pre-formatted
    /// messages. Only do minimal sanitisation here for legacy records.
    private var cleanMessage: String {
        var msg = record.message

        // ── Legacy: convert "USD 700.0" → "$700.00" ─────────────────────────
        if let range = msg.range(of: #"(USD|KHR|EUR)\s+([\d.]+)"#, options: .regularExpression) {
            let matched = String(msg[range])
            let parts   = matched.split(separator: " ")
            if parts.count == 2, let amt = Double(parts[1]) {
                let currency  = String(parts[0])
                let symbol    = currency == "USD" ? "$" : (currency == "KHR" ? "KHR " : "€")
                let formatted = symbol + String(format: "%,.2f", amt)
                msg = msg.replacingOccurrences(of: matched, with: formatted)
            }
        }

        // ── Legacy: shorten bare long account numbers not already masked ─────
        if let regex = try? NSRegularExpression(pattern: #"(?<!···)\b(\d{8,})\b"#) {
            let nsMsg   = msg as NSString
            let range   = NSRange(location: 0, length: nsMsg.length)
            let matches = regex.matches(in: msg, range: range).reversed()
            var result  = msg
            for match in matches {
                if let swiftRange = Range(match.range, in: msg) {
                    let fullNumber = String(msg[swiftRange])
                    let last4      = String(fullNumber.suffix(4))
                    result = result.replacingCharacters(in: swiftRange, with: "···\(last4)")
                }
            }
            msg = result
        }

        return msg
    }

    /// Extract a formatted amount string from the message for the footer badge.
    private var extractedAmount: String? {
        let patterns: [String] = [
            #"[$€]\d[\d,]*\.?\d*"#,
            #"KHR\s\d[\d,]*\.?\d*"#
        ]
        for pattern in patterns {
            if let range = record.message.range(of: pattern, options: .regularExpression) {
                return String(record.message[range])
            }
        }
        // Legacy: "USD 700" format
        if let range = record.message.range(of: #"(USD|KHR|EUR)\s+([\d.]+)"#, options: .regularExpression) {
            let matched = String(record.message[range])
            let parts   = matched.split(separator: " ")
            if parts.count == 2, let amt = Double(parts[1]) {
                let currency = String(parts[0])
                let symbol   = currency == "USD" ? "$" : (currency == "KHR" ? "KHR " : "€")
                return symbol + String(format: "%,.2f", amt)
            }
        }
        return nil
    }

    private var iconName: String {
        if isReceived   { return "arrow.down.circle.fill" }
        if isSent       { return "arrow.up.circle.fill" }
        if isDeposit    { return "plus.circle.fill" }
        if isWithdrawal { return "minus.circle.fill" }
        return "creditcard.circle.fill"
    }

    private var iconColor: Color {
        if isReceived   { return .green }
        if isSent       { return .blue }
        if isDeposit    { return .teal }
        if isWithdrawal { return .orange }
        return .purple
    }

    private var iconBg: Color { iconColor.opacity(0.12) }
}

// MARK: - Status Pill

struct StatusPill: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status.uppercased() {
        case "SENT":         return "Sent"
        case "DELIVERED":    return "Delivered"
        case "FAILED":       return "Failed"
        case "RATE_LIMITED": return "Delayed"
        default:             return status.capitalized
        }
    }

    private var color: Color {
        switch status.uppercased() {
        case "SENT", "DELIVERED": return .green
        case "FAILED":            return .red
        case "RATE_LIMITED":      return .orange
        default:                  return .gray
        }
    }
}

// MARK: - Rounded Corner helper (individual corners)

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preferences Form

struct PreferencesFormView: View {
    @State private var pref: NotificationPreference
    let vm: NotificationsViewModel
    let userId: String

    init(pref: NotificationPreference, vm: NotificationsViewModel, userId: String) {
        _pref = State(initialValue: pref)
        self.vm = vm
        self.userId = userId
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $pref.pushEnabled) {
                    Label("Push Notifications", systemImage: "bell.fill")
                }
                Toggle(isOn: $pref.emailEnabled) {
                    Label("Email Notifications", systemImage: "envelope.fill")
                }
                Toggle(isOn: $pref.smsEnabled) {
                    Label("SMS Notifications", systemImage: "message.fill")
                }
            } header: {
                Text("Channels")
            } footer: {
                Text("Choose how you want to receive transaction notifications.")
            }

            Section("Content") {
                Toggle(isOn: $pref.marketingEnabled) {
                    Label("Promotions & Offers", systemImage: "tag.fill")
                }
            }

            Section("Language") {
                Picker("Locale", selection: $pref.locale) {
                    Text("English").tag("en")
                    Text("ខ្មែរ (Khmer)").tag("km")
                }
                .pickerStyle(.menu)
            }

            Section {
                Button {
                    Task { await vm.savePreference(pref) }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isSavingPreference {
                            ProgressView()
                        } else {
                            Label(
                                vm.saveSuccess ? "Saved!" : "Save Preferences",
                                systemImage: vm.saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down"
                            )
                            .bold()
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(vm.saveSuccess ? .green : .blue)
                .disabled(vm.isSavingPreference)
            }
        }
    }
}

// MARK: - StatusBadge (backwards compat alias)
typealias StatusBadge = StatusPill

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationsView(vm: NotificationsViewModel())
            .environmentObject(AuthViewModel())
    }
}
