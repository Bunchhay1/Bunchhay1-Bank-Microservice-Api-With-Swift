import SwiftUI
import Combine

// MARK: - In-App Notification Model

struct InAppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let timestamp: Date = Date()

    enum NotificationType {
        case success, failure, warning, info

        var color: Color {
            switch self {
            case .success: return Color.titanInflow
            case .failure: return Color.titanOutflow
            case .warning: return Color.orange
            case .info:    return Color.titanPrimary
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info:    return "bell.badge.fill"
            }
        }
    }
}

// MARK: - Manager

/// Global in-app banner manager.
/// Non-intrusive HUD that delivers notifications smoothly without stealing focus.
@MainActor
final class InAppNotificationManager: ObservableObject {

    static let shared = InAppNotificationManager()

    @Published var current: InAppNotification?
    @Published var unreadCount: Int = 0

    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Show a banner for `duration` seconds then auto-dismiss smoothly.
    func show(_ title: String, message: String, type: InAppNotification.NotificationType, duration: Double = 3.5) {
        dismissTask?.cancel()
        Haptics.tap()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            current = InAppNotification(title: title, message: message, type: type)
        }
        unreadCount += 1

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            current = nil
        }
    }

    func clearBadge() {
        unreadCount = 0
    }
}

// MARK: - Ultra-Smooth Glass Banner View

struct InAppBannerView: View {
    let notification: InAppNotification
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Glowing status icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: notification.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(notification.type.color)
            }

            // Notification content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.titanDark)
                        .lineLimit(1)
                    Spacer()
                    Text("now")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.titanSecondary)
                }

                Text(notification.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.titanSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Close button
            Button(action: {
                Haptics.tap()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.titanSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .bouncyButton(scale: 0.90)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color(UIColor.systemBackground).opacity(0.85))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.60), .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .offset(y: min(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -20 || value.velocity.height < -300 {
                        Haptics.tap()
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Non-Intrusive View Modifier

struct InAppNotificationOverlay: ViewModifier {
    @ObservedObject private var manager = InAppNotificationManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let notif = manager.current {
                VStack {
                    InAppBannerView(notification: notif) {
                        manager.dismiss()
                    }
                    .allowsHitTesting(true)
                    Spacer()
                }
                .ignoresSafeArea(edges: .all)
                .padding(.top, topSafeArea + 6)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))
                .zIndex(9999)
                .allowsHitTesting(true)
            }
        }
    }

    private var topSafeArea: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top) ?? 48
    }
}

extension View {
    /// Attach this once to the root view to enable non-intrusive in-app banners everywhere.
    func inAppNotificationOverlay() -> some View {
        modifier(InAppNotificationOverlay())
    }
}
