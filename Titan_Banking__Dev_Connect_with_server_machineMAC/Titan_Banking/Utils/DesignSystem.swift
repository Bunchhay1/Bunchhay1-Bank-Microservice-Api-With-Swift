import SwiftUI
import UIKit

// MARK: - Color Tokens (Global Modern Banking Brand Palette)
extension Color {
    static let titanBackground   = Color(UIColor.systemBackground)
    static let titanSurface      = Color(UIColor.secondarySystemBackground)
    static let titanPrimary      = Color(red: 0.10, green: 0.38, blue: 0.85)   // Titan Blue #1A61D9
    static let titanPrimaryDark  = Color(red: 0.05, green: 0.22, blue: 0.65)   // Dark Blue #0D38A6
    static let titanNavy         = Color(red: 0.06, green: 0.16, blue: 0.58)
    static let titanAccent       = Color(red: 0.10, green: 0.38, blue: 0.85)   // Button accent
    static let titanDark         = Color(red: 0.06, green: 0.08, blue: 0.12)   // Near-black
    static let titanInflow       = Color(red: 0.08, green: 0.65, blue: 0.42)   // Inflow emerald
    static let titanOutflow      = Color(red: 0.88, green: 0.22, blue: 0.22)   // Outflow crimson
    static let titanSecondary    = Color(UIColor.secondaryLabel)
    static let titanRedLight     = Color(red: 0.10, green: 0.38, blue: 0.85).opacity(0.08)
}

// MARK: - Tactile Haptic Engine
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Bouncy Touch Button Style
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension View {
    func bouncyButton(scale: CGFloat = 0.95) -> some View {
        self.buttonStyle(ScaleButtonStyle(scale: scale))
    }
}

// MARK: - Floating Glass Back / Close Button
struct FloatingBackButton: View {
    var icon: String = "xmark"
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .bouncyButton(scale: 0.90)
    }
}

// MARK: - Floating Micro Toast Modifier
struct ToastMessage: Equatable {
    let icon: String
    let message: String
}

struct TitanToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let t = toast {
                    HStack(spacing: 8) {
                        Image(systemName: t.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.titanPrimary)
                        Text(t.message)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.titanDark)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                    )
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    .zIndex(999)
                    .onAppear {
                        Haptics.tap()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                toast = nil
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: toast)
    }
}

extension View {
    func titanToast(toast: Binding<ToastMessage?>) -> some View {
        self.modifier(TitanToastModifier(toast: toast))
    }
}

// MARK: - Shimmer Skeleton
struct SkeletonView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(Color(UIColor.systemFill))
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.5)
                    .offset(x: phase * (w + w * 0.5))
                )
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

extension View {
    func skeletonCorner(_ radius: CGFloat = 8) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Card Container
struct TitanCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .background(Color.titanBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Glassmorphic Container
struct TitanGlassContainer<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder _ content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Primary Button
struct TitanPrimaryButton: View {
    let label: String
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(label)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isEnabled ? Color.titanPrimary : Color.titanPrimary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: isEnabled ? Color.titanPrimary.opacity(0.35) : .clear, radius: 8, y: 4)
        }
        .bouncyButton(scale: 0.97)
        .disabled(isLoading)
    }
}

// MARK: - Amount Display
struct MonoAmount: View {
    let value: Double
    let code: String
    let size: CGFloat

    var body: some View {
        Text(value, format: .currency(code: code))
            .font(.system(size: size, weight: .bold, design: .rounded))
    }
}
