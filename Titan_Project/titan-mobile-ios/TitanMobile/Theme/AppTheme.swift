import SwiftUI

// MARK: - Brand Colors
extension Color {

    // ── Primary Brand ────────────────────────────────────────────
    static let titanBlue        = Color(hex: "#1535D0")
    static let titanBlueMid     = Color(hex: "#2150F0")
    static let titanBlueLight   = Color(hex: "#1A8CFF")
    static let titanBlueSoft    = Color(hex: "#E8EDFB")
    static let titanBlueDark    = Color(hex: "#0F2899")

    // ── Orange Accent (Services section grade) ───────────────────
    static let orangeStart      = Color(hex: "#FF8C00")   // deep orange
    static let orangeMid        = Color(hex: "#FF6B00")   // burnt orange
    static let orangeEnd        = Color(hex: "#FF4500")   // red-orange
    static let orangeSoft       = Color(hex: "#FFF3E6")   // pale orange bg
    static let orangeGlow       = Color(hex: "#FF8C00").opacity(0.25)

    // ── Service Icon Palette (cute + vivid) ──────────────────────
    static let iconTransfer     = Color(hex: "#4F78FF")   // electric blue
    static let iconQR           = Color(hex: "#00C48C")   // mint
    static let iconReceive      = Color(hex: "#A855F7")   // violet
    static let iconDeposit      = Color(hex: "#10B981")   // emerald
    static let iconWithdraw     = Color(hex: "#F43F5E")   // rose
    static let iconLoans        = Color(hex: "#F97316")   // orange
    static let iconSavings      = Color(hex: "#EAB308")   // amber
    static let iconMore         = Color(hex: "#64748B")   // slate

    // ── Surface & Background ─────────────────────────────────────
    static let appBG            = Color(hex: "#F2F5FC")
    static let cardBG           = Color.white
    static let sectionBG        = Color.white

    // ── Text ─────────────────────────────────────────────────────
    static let textPrimary      = Color(hex: "#111827")
    static let textSecondary    = Color(hex: "#6B7280")
    static let textPositive     = Color(hex: "#059669")
    static let textNegative     = Color(hex: "#DC2626")

    // ── Hex Init ─────────────────────────────────────────────────
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255, (int>>8)*17, (int>>4&0xF)*17, (int&0xF)*17)
        case 6:  (a,r,g,b) = (255, int>>16, int>>8&0xFF, int&0xFF)
        case 8:  (a,r,g,b) = (int>>24, int>>16&0xFF, int>>8&0xFF, int&0xFF)
        default: (a,r,g,b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r)/255,
                  green:   Double(g)/255,
                  blue:    Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - Gradients
struct AppGradient {

    /// Orange gradient for Services header & section frame
    static let orangeGrade = LinearGradient(
        colors: [Color(hex: "#FF8C00"), Color(hex: "#FF5500"), Color(hex: "#FF3D00")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm orange glow for icon shadows
    static let orangeGlow = LinearGradient(
        colors: [Color(hex: "#FFAD33"), Color(hex: "#FF6600")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Hero header gradient
    static let heroBlue = LinearGradient(
        colors: [Color(hex: "#1535D0"), Color(hex: "#2150F0"), Color(hex: "#1A8CFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Balance card gradient
    static let balanceCard = LinearGradient(
        colors: [Color(hex: "#1A3CC8"), Color(hex: "#2563EB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography (rounded = friendly/cute)
struct AppFont {
    static func regular  (_ size: CGFloat) -> Font { .system(size: size, weight: .regular,  design: .rounded) }
    static func medium   (_ size: CGFloat) -> Font { .system(size: size, weight: .medium,   design: .rounded) }
    static func semibold (_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func bold     (_ size: CGFloat) -> Font { .system(size: size, weight: .bold,     design: .rounded) }
    static func heavy    (_ size: CGFloat) -> Font { .system(size: size, weight: .heavy,    design: .rounded) }
}

// MARK: - View Modifiers
extension View {
    func cardShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 5)
    }
    func softShadow() -> some View {
        shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    func orangeIconShadow() -> some View {
        shadow(color: Color.orangeStart.opacity(0.4), radius: 10, x: 0, y: 5)
    }
    func coloredIconShadow(_ color: Color) -> some View {
        shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}
