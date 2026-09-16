import SwiftUI

// MARK: - Home View (root scroll page)
struct HomeView: View {
    let user = BankUser.sample
    @State private var balanceHidden = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Hero Header (blue gradient) ──────────────────
                HeroHeaderView(user: user, balanceHidden: $balanceHidden)

                // ── Content Sheet (slides up over hero) ──────────
                VStack(spacing: 16) {

                    // Balance card overlaps hero
                    BalanceCardView(user: user, isHidden: balanceHidden)
                        .padding(.horizontal, 16)
                        .offset(y: -32)
                        .padding(.bottom, -32)

                    // ★ Services — orange gradient design
                    ServiceGridView()
                        .padding(.top, 12)

                    // Recent transactions
                    RecentTransactionsView(transactions: Transaction.samples)
                        .padding(.top, 4)

                    Spacer().frame(height: 24)
                }
                .background(
                    Color.appBG
                        .clipShape(RoundedCorner(radius: 34, corners: [.topLeft, .topRight]))
                )
                .offset(y: -34)
            }
        }
        .background(AppGradient.heroBlue.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Hero Header
struct HeroHeaderView: View {
    let user: BankUser
    @Binding var balanceHidden: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppGradient.heroBlue
                .frame(height: 230)

            // Decorative blobs
            Circle().fill(Color.white.opacity(0.05))
                .frame(width: 200).offset(x: -50, y: -50)
            Circle().fill(Color.white.opacity(0.04))
                .frame(width: 140).offset(x: 260, y: 50)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // Logo
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TITAN")
                                .font(AppFont.heavy(16))
                                .foregroundColor(.white)
                            Text("Mobile Banking")
                                .font(AppFont.regular(10))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    // QR & Bell
                    HStack(spacing: 10) {
                        TopBarButton(icon: "qrcode.viewfinder")
                        TopBarButton(icon: "bell.fill", badge: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)

                // Greeting
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(user.greetingKhmer)
                                .font(AppFont.regular(13))
                                .foregroundColor(Color.white.opacity(0.75))
                            Text("·")
                                .foregroundColor(Color.white.opacity(0.4))
                            Text(user.greeting)
                                .font(AppFont.regular(13))
                                .foregroundColor(Color.white.opacity(0.75))
                            Text(user.emoji)
                        }
                        Text(user.name)
                            .font(AppFont.bold(22))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { balanceHidden.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: balanceHidden ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 12))
                            Text(balanceHidden ? "Show" : "Hide")
                                .font(AppFont.medium(13))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
    }
}

// MARK: - Balance Card
struct BalanceCardView: View {
    let user: BankUser
    let isHidden: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppGradient.balanceCard)

            // Shine blob
            Ellipse()
                .fill(Color.white.opacity(0.07))
                .frame(width: 160, height: 100)
                .rotationEffect(.degrees(-30))
                .offset(x: 170, y: 10)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(user.accountType, systemImage: "creditcard.fill")
                        .font(AppFont.medium(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    Spacer()
                    Text(user.currency)
                        .font(AppFont.bold(13))
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer().frame(height: 18)
                Text("Available Balance")
                    .font(AppFont.regular(12))
                    .foregroundColor(Color.white.opacity(0.65))
                Spacer().frame(height: 6)
                if isHidden {
                    HStack(spacing: 5) {
                        ForEach(0..<6, id: \.self) { _ in
                            Circle().fill(Color.white).frame(width: 9, height: 9)
                        }
                    }
                    .frame(height: 36)
                } else {
                    Text("US$\(user.balance, specifier: "%.2f")")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer().frame(height: 10)
                Text(user.accountNumber)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            .padding(22)
        }
        .frame(height: 162)
        .cardShadow()
    }
}

// MARK: - Top Bar Icon Button
struct TopBarButton: View {
    let icon: String
    var badge = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {} label: {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            if badge {
                Circle().fill(Color(hex: "#EF4444"))
                    .frame(width: 10, height: 10)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

#Preview { HomeView() }
