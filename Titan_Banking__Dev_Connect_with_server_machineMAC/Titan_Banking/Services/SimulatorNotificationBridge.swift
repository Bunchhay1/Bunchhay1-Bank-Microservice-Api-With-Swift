import Foundation
import UserNotifications
import UIKit

// MARK: - SimulatorNotificationBridge
//
// Provides TWO notification paths that work together:
//
// Path 1 — File-watcher bridge (same Mac, cross-simulator)
//   • Sender writes /tmp/titan_transfer_<toAccountNumber>.json
//   • Receiver watches that file → fires immediately when written
//   • Works because all simulator processes share the host Mac's /tmp
//
// Path 2 — Polling-triggered local push (works without a real APNs key)
//   • NotificationsViewModel.fetchHistory() detects new TRANSFER_RECEIVED records
//   • Calls SimulatorNotificationBridge.shared.fireSystemPush(title:body:)
//   • UNUserNotificationCenter schedules the push → phone shows banner + sound
//     even when app is in background or just suspended
//
// Path 2 is the primary path for local Docker testing.
// Path 1 is a secondary real-time bridge for instant cross-simulator delivery.
// On a real device with APNs keys configured, the backend sends a real APNs push
// that arrives instantly without any polling.

private struct TransferPayload: Codable {
    let fromAccountNumber: String
    let toAccountNumber: String
    let amount: Double
    let currency: String
    let timestamp: TimeInterval
}

final class SimulatorNotificationBridge: @unchecked Sendable {

    static let shared = SimulatorNotificationBridge()
    private init() {}

    // One DispatchSource per watched account number
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var lastHandledTimestamp: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "com.titan.bridge", qos: .utility)

    // MARK: - Public API: fire a system-level local notification
    //
    // Call this from NotificationsViewModel when polling detects a new
    // TRANSFER_RECEIVED record. The system shows the banner with sound
    // even if the app is in background / suspended.

    func fireSystemPush(title: String, body: String) {
        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default   // .defaultCriticalSound requires entitlement — not available on simulator
        content.badge    = NSNumber(value: (UIApplication.shared.applicationIconBadgeNumber) + 1)

        // 0.5 s delay so the notification fires "outside" the current runloop tick
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "titan-push-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ [Bridge] Local push failed: \(error.localizedDescription)")
            } else {
                print("🔔 [Bridge] Local push scheduled: \(title) — \(body)")
            }
        }
    }

    // MARK: - Sender (cross-simulator file-watcher path)

    /// Call after a successful transfer. Writes a JSON payload to /tmp so the
    /// receiver's file watcher fires immediately on the same Mac.
    func broadcastTransfer(toAccountNumber: String,
                           fromAccountNumber: String,
                           amount: Double,
                           currency: String = "USD") {
        let payload = TransferPayload(
            fromAccountNumber: fromAccountNumber,
            toAccountNumber:   toAccountNumber,
            amount:            amount,
            currency:          currency,
            timestamp:         Date().timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = payloadURL(for: toAccountNumber)

        do {
            try data.write(to: url, options: .atomic)
            print("📡 [Bridge] Wrote payload → \(url.lastPathComponent)")
        } catch {
            print("❌ [Bridge] Failed to write payload: \(error)")
        }
    }

    // MARK: - Receiver (cross-simulator file-watcher path)

    /// Call after accounts load. Creates a file watcher for each account number.
    func startListening(forAccountNumbers accountNumbers: [String]) {
        stopListening()
        for accountNumber in accountNumbers {
            watchFile(for: accountNumber)
        }
        print("👂 [Bridge] Watching \(accountNumbers.count) account(s): \(accountNumbers)")
    }

    func stopListening() {
        sources.values.forEach { $0.cancel() }
        sources.removeAll()
        lastHandledTimestamp.removeAll()
    }

    // MARK: - Private

    private func watchFile(for accountNumber: String) {
        let url  = payloadURL(for: accountNumber)
        let path = url.path

        // Ensure the file exists so we can open an fd on it
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("❌ [Bridge] Cannot open \(path) for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleFileEvent(accountNumber: accountNumber, path: path)
        }

        source.setCancelHandler { close(fd) }

        sources[accountNumber] = source
        source.resume()
    }

    private func handleFileEvent(accountNumber: String, path: String) {
        guard
            let data    = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let payload = try? JSONDecoder().decode(TransferPayload.self, from: data)
        else { return }

        // De-duplicate: ignore if we already handled this exact timestamp
        if let last = lastHandledTimestamp[accountNumber], last >= payload.timestamp { return }

        // Ignore stale payloads (> 30 s old)
        let age = Date().timeIntervalSince1970 - payload.timestamp
        guard age < 30 else { return }

        lastHandledTimestamp[accountNumber] = payload.timestamp

        let amountStr = SmartCurrencyConverter.format(amount: payload.amount, currency: payload.currency)
        let title     = "Money Received"
        let body      = "You received \(amountStr) from ···\(String(payload.fromAccountNumber.suffix(4)))"

        print("🔔 [Bridge] File event: \(body)")

        Task { @MainActor in
            InAppNotificationManager.shared.show(title, message: body, type: .success)
            Self.shared.fireSystemPush(title: title, body: body)
        }
    }

    private func payloadURL(for accountNumber: String) -> URL {
        URL(fileURLWithPath: "/tmp/titan_transfer_\(accountNumber).json")
    }
}
