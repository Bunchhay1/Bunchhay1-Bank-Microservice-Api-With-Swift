import SwiftUI

// MARK: - Services Grid — Orange Header + Vivid Coloured Body
struct ServiceGridView: View {
    let services = ServiceItem.all
    @State private var pressedID: UUID?

    // ★ Body background: vivid orange-to-purple gradient — clearly visible
    private let bodyGradient = LinearGradient(
        colors: [
            Color(hex: "#FF6B00"),   // strong orange (top)
            Color(hex: "#FF8C42"),   // warm amber
            Color(hex: "#FFB347"),   // golden orange
            Color(hex: "#FFC973"),   // peach gold (bottom)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {

            // ── Header: darker orange band ─────────────────────────
            serviceHeader

            // ── Body: vivid orange gradient background ─────────────
            ZStack {
                // Fill the entire body area
                bodyGradient

                // Decorative blobs inside body
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 120)
                    .offset(x: -80, y: 30)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 90)
                    .offset(x: 120, y: -10)

                // The icon grid sits on top
                serviceGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(hex: "#FF6B00").opacity(0.35), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.06),           radius: 6,  x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Header strip
    private var serviceHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Header is deeper/darker orange than the body
            LinearGradient(
                colors: [Color(hex: "#E84800"), Color(hex: "#FF4500")],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 64)

            // Shine blobs
            Circle().fill(Color.white.opacity(0.10))
                .frame(width: 80).offset(x: 250, y: -12)
            Circle().fill(Color.white.opacity(0.07))
                .frame(width: 50).offset(x: 300, y: 16)

            // Title + See all
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("សេវាកម្ម")
                        .font(AppFont.regular(11))
                        .foregroundColor(Color.white.opacity(0.75))
                    Text("Services")
                        .font(AppFont.bold(18))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {} label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(AppFont.medium(12))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.20))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    // MARK: - 4-column icon grid
    private var serviceGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
            spacing: 20
        ) {
            ForEach(services) { item in
                ServiceIconCell(
                    item: item,
                    isPressed: pressedID == item.id,
                    onPress: { pressing in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            pressedID = pressing ? item.id : nil
                        }
                    },
                    onTap: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
            }
        }
    }
}

// MARK: - Single icon cell
struct ServiceIconCell: View {
    let item: ServiceItem
    let isPressed: Bool
    let onPress: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {

                // Icon circle
                ZStack {
                    // Halo
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 62, height: 62)

                    // Gradient fill
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: item.bgGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)

                    // Glass shine
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.40), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 50, height: 50)

                    // SF Symbol
                    Image(systemName: item.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                .scaleEffect(isPressed ? 0.86 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isPressed)

                // Label — white text on coloured background
                Text(item.title)
                    .font(AppFont.semibold(11))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress(true)  }
                .onEnded   { _ in onPress(false) }
        )
    }
}

// MARK: - Helper
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

// MARK: - Preview
#Preview("Services — Vivid Orange Body") {
    ZStack {
        Color(hex: "#F2F5FC").ignoresSafeArea()
        ServiceGridView()
            .padding(.top, 60)
    }
}
