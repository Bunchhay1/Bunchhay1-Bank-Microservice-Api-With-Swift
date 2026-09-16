import Foundation
import SwiftUI
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {

    // ── State ─────────────────────────────────────────────────────────────────
    @Published var records: [NotificationAuditRecord] = []
    @Published var preference: NotificationPreference?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSavingPreference = false
    @Published var saveSuccess = false
    @Published var unreadCount: Int = 0

    // The count seen on the PREVIOUS poll cycle.
    private var lastSeenCount: Int = 0

    // The timestamp of the newest record seen on first load.
    private var lastSeenTimestamp: Date? = nil

    // Tracks transactionIds we already fired a banner for — prevents any duplicate
    // regardless of timestamp comparison accuracy.
    private var firedNotificationIds: Set<String> = []

    private var pollTask: Task<Void, Never>?

    // ── Fetch audit history for the logged-in user ────────────────────────────
    func fetchHistory(accountId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fresh = try await APIClient.shared.notificationRequest(
                NotificationAuditEndpoint.getByAccount(accountId),
                responseType: [NotificationAuditRecord].self
            )

            // ── FIRST LOAD ────────────────────────────────────────────────────
            if lastSeenCount == 0 {
                records = fresh
                lastSeenCount = fresh.count

                // Record the timestamp of the newest item as the high-water mark.
                // Do NOT fire any banners on first load — this prevents the app
                // from re-showing notifications that already appeared before launch.
                lastSeenTimestamp = fresh.first.flatMap { parseDate($0.attemptedAt) }
                return
            }

            // ── SUBSEQUENT POLLS ──────────────────────────────────────────────
            // Find records strictly newer than our high-water mark.
            var newItems: [NotificationAuditRecord] = []

            if let lastTs = lastSeenTimestamp {
                newItems = fresh.filter { item in
                    guard let date = parseDate(item.attemptedAt) else { return false }
                    return date > lastTs
                }
            } else {
                let newCount = fresh.count - lastSeenCount
                if newCount > 0 {
                    newItems = Array(fresh.prefix(newCount))
                }
            }

            if !newItems.isEmpty {
                unreadCount += newItems.count

                // Update high-water mark to the newest record we just saw
                if let newestDate = newItems.compactMap({ parseDate($0.attemptedAt) }).max() {
                    lastSeenTimestamp = newestDate
                }

                for item in newItems.prefix(2) {
                    // Hard dedup: never fire the same transactionId twice
                    guard !firedNotificationIds.contains(item.transactionId) else { continue }
                    firedNotificationIds.insert(item.transactionId)
                    let (title, body) = parseBannerContent(for: item)
                    // Show fluid in-app HUD banner
                    InAppNotificationManager.shared.show(title, message: body, type: .success)
                    // Also schedule local system notification
                    SimulatorNotificationBridge.shared.fireSystemPush(title: title, body: body)
                }
            }

            records = fresh
            lastSeenCount = fresh.count

        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }
    }

    /// GET /api/audit/user/{username}
    func fetchAuditByUser(_ username: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            records = try await APIClient.shared.notificationRequest(
                NotificationServiceEndpoint.auditByUser(username),
                responseType: [NotificationAuditRecord].self
            )
            lastSeenCount = records.count
            lastSeenTimestamp = records.first.flatMap { parseDate($0.attemptedAt) }
        } catch {
            errorMessage = "Audit by user failed: \(error.localizedDescription)"
        }
    }

    /// GET /api/audit/transaction/{transactionId}
    func fetchAuditByTransaction(_ transactionId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            records = try await APIClient.shared.notificationRequest(
                NotificationServiceEndpoint.auditByTransaction(transactionId),
                responseType: [NotificationAuditRecord].self
            )
            lastSeenCount = records.count
            lastSeenTimestamp = records.first.flatMap { parseDate($0.attemptedAt) }
        } catch {
            errorMessage = "Audit by transaction failed: \(error.localizedDescription)"
        }
    }

    // ── Start polling every 3 seconds for near real-time updates ───────────────
    func startPolling(accountId: String) {
        stopPolling()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await fetchHistory(accountId: accountId)
            }
        }
    }

    /// Reset state and start polling fresh for the given user.
    /// Called after login or when the username becomes available.
    func resetAndStartPolling(accountId: String) {
        stopPolling()
        lastSeenCount = 0
        lastSeenTimestamp = nil
        firedNotificationIds = []
        unreadCount = 0
        records = []
        errorMessage = nil
        Task {
            await fetchHistory(accountId: accountId)
            startPolling(accountId: accountId)
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // ── Fetch preference ──────────────────────────────────────────────────────
    func fetchPreference(userId: String) async {
        do {
            preference = try await APIClient.shared.notificationRequest(
                NotificationPreferenceEndpoint.getPreference(userId),
                responseType: NotificationPreference.self
            )
        } catch {
            // Non-fatal — preference panel shows defaults
        }
    }

    // ── Save preference ───────────────────────────────────────────────────────
    func savePreference(_ pref: NotificationPreference) async {
        isSavingPreference = true
        saveSuccess = false
        defer { isSavingPreference = false }
        do {
            preference = try await APIClient.shared.notificationRequest(
                NotificationPreferenceEndpoint.updatePreference(pref),
                responseType: NotificationPreference.self
            )
            saveSuccess = true
        } catch {
            errorMessage = "Failed to save preferences: \(error.localizedDescription)"
        }
    }

    // ── Mark all as read ──────────────────────────────────────────────────────
    func markAllRead() {
        unreadCount = 0
        InAppNotificationManager.shared.clearBadge()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    func statusColor(for record: NotificationAuditRecord) -> Color {
        switch record.status.uppercased() {
        case "SENT", "DELIVERED": return .green
        case "FAILED":            return .red
        case "RATE_LIMITED":      return .orange
        default:                  return .gray
        }
    }

    func channelIcon(for record: NotificationAuditRecord) -> String {
        switch record.channel.uppercased() {
        case "EMAIL": return "envelope.fill"
        case "SMS":   return "message.fill"
        case "PUSH":  return "bell.fill"
        default:      return "bell.badge.fill"
        }
    }

    func formatDate(_ raw: String) -> String {
        // Format 1: ISO "2026-07-09T16:45:13.123Z"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            return dateFormatter.string(from: date)
        }
        // Format 2: "2026-07-09 16:45:13"
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = fmt.date(from: raw) {
            return dateFormatter.string(from: date)
        }
        return raw.replacingOccurrences(of: "T", with: " ").prefix(19).description
    }

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // ── Parse attemptedAt which backend sends as [y,M,d,H,m,s,nano] array ────
    // NotificationAuditRecord.attemptedAt is already normalised to a String
    // by the custom decoder, so we just parse that string.
    private func parseDate(_ raw: String) -> Date? {
        // "2026-07-09 16:45:13" — backend sends in server local time, parse without forcing UTC
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = fmt.date(from: raw) { return d }

        // ISO fallback "2026-07-09T16:45:13.123Z"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Smart banner content parser
    //
    // Handles BOTH message formats:
    //
    // New (post-fix):
    //   "You transferred $10.00 to navatra (Acc: ···5586). Ref: TXN-28. 10/07/2026 12:30"
    //   "You received $10.00 from navatra (Acc: ···5586). Ref: TXN-28. 10/07/2026 12:30"
    //
    // Old (pre-fix, still in DB):
    //   "You received $30.00 from account ···5586. Ref: 16-recv"
    //   "Transferred USD 50.00 to vanda (Acc: 001***952). Ref: TXN-36."
    // ─────────────────────────────────────────────────────────────────────────
    private func parseBannerContent(for record: NotificationAuditRecord) -> (String, String) {
        let msg = record.message.lowercased()

        if msg.hasPrefix("you received") {
            let amount = extractAmount(from: record.message) ?? ""
            let from = extractNameAfterKeyword("from", in: record.message)
                    ?? extractFirstMaskedAccount(from: record.message)
                    ?? "another account"
            return ("Money Received", "\(amount) from \(from)")
        }

        if msg.hasPrefix("you transferred") || msg.hasPrefix("transferred") {
            let amount = extractAmount(from: record.message) ?? ""
            let to = extractNameAfterKeyword("to", in: record.message)
                  ?? extractFirstMaskedAccount(from: record.message)
                  ?? "recipient"
            return ("Transaction Complete", "\(amount) to \(to)")
        }

        if msg.hasPrefix("deposit") {
            let amount = extractAmount(from: record.message) ?? ""
            return ("Deposit Confirmed", "\(amount) deposited successfully")
        }

        if msg.hasPrefix("withdrawal") {
            let amount = extractAmount(from: record.message) ?? ""
            return ("Withdrawal Confirmed", "\(amount) withdrawn successfully")
        }

        // Promotion / deposit bonus reward
        if msg.hasPrefix("bonus:") {
            let amount = extractAmount(from: record.message) ?? "$2.00"
            return ("Promotion Reward", "\(amount) deposit bonus added to your account")
        }

        // Generic fallback
        let truncated = record.message.count > 60
            ? String(record.message.prefix(60)) + "…"
            : record.message
        return ("Transaction Update", truncated)
    }

    // ── Extract amount: "$30.00", "USD 50.00", "KHR 20,500", "20,500 ៛" ───────────────────
    private func extractAmount(from message: String) -> String? {
        let patterns = [
            #"US\$?\s*\d[\d,]*\.?\d*"#,
            #"[$€]\d[\d,]*\.?\d*"#,
            #"KHR\s*\d[\d,]*\.?\d*"#,
            #"\d[\d,]*\.?\d*\s*៛"#,
            #"USD\s*\d[\d,]*\.?\d*"#
        ]
        for pattern in patterns {
            if let range = message.range(of: pattern, options: .regularExpression) {
                return String(message[range])
            }
        }
        return nil
    }

    // ── Extract name/account after a keyword like "from" or "to" ─────────────
    // Examples:
    //   "from navatra (Acc…"     → "navatra"
    //   "from account ···5586"   → "···5586"   (skips the word "account")
    //   "to vanda (Acc…"         → "vanda"
    private func extractNameAfterKeyword(_ keyword: String, in message: String) -> String? {
        // Pattern: keyword + space + captured token, stopping at " (", ".", ","
        let pattern = "(?i)(?<=\(keyword) )(.+?)(?= \\(|\\.|,|$)"
        guard let range = message.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        var name = String(message[range]).trimmingCharacters(in: .whitespaces)

        // If the token is "account" (literal word), skip it and look for the masked number
        if name.lowercased() == "account" {
            return extractFirstMaskedAccount(from: message)
        }

        // If it starts with a digit or "···", it's an account number not a name
        if name.hasPrefix("···") || name.first?.isNumber == true {
            return name
        }

        return name.isEmpty ? nil : name
    }

    // ── Extract first "···XXXX" masked account in message ────────────────────
    private func extractFirstMaskedAccount(from message: String) -> String? {
        // Matches both "···5586" (new format) and "001***586" (old format → last 4)
        if let range = message.range(of: #"···\d{4}"#, options: .regularExpression) {
            return String(message[range])
        }
        // Old format: "001***586" → return "···0586" style
        if let range = message.range(of: #"\d{3}\*{3}\d{3,4}"#, options: .regularExpression) {
            let acct = String(message[range])
            return "···" + acct.suffix(4)
        }
        return nil
    }
}
