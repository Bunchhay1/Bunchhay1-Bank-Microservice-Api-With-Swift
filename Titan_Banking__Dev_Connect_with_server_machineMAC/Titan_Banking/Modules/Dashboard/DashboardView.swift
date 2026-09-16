import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var inAppNotif = InAppNotificationManager.shared
    @StateObject private var accountVM = AccountViewModel()
    @StateObject private var txVM = TransactionViewModel()

    @State private var transferStep: TransferStep? = nil
    @State private var selectedTx: TransactionResponse? = nil
    @State private var prefillToAccount: String? = nil
    @State private var prefillAmount: Double? = nil
    @State private var prefillCurrency: String? = nil
    @State private var selectedAccountIndex = 0
    @State private var showQrPay      = false
    @State private var showAtmWithdraw = false
    @State private var showLoans      = false
    @State private var showPromotions = false
    @State private var showMoreServices = false
    @State private var balanceHidden  = false
    @State private var toast: ToastMessage? = nil
    @State private var realTimeTimer: Task<Void, Never>? = nil

    var onNotificationBellTapped: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.secondarySystemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    abaStyleHeader
                    accountCarousel
                        .padding(.top, -44)
                        .zIndex(2)
                    quickActionGrid
                        .padding(.top, 20)
                    recentTransactions
                        .padding(.top, 20)
                    Spacer().frame(height: 40)
                }
            }
            .refreshable { await loadData() }
        }
        .navigationBarHidden(true)
        .task {
            await loadData()
            startRealTimeSync()
        }
        .onDisappear {
            realTimeTimer?.cancel()
        }
        .sheet(item: $selectedTx) { tx in
            let myNumbers = Set(accountVM.accounts.map { $0.accountNumber })
            TransactionDetailSheet(
                tx: tx,
                myAccountNumbers: myNumbers,
                onTransferBack: { counterpartyAccount, _, currency in
                    selectedTx = nil
                    prefillToAccount = counterpartyAccount
                    prefillAmount = nil
                    prefillCurrency = currency
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        transferStep = .amount(mode: .transfer)
                    }
                }
            )
        }
        .fullScreenCover(item: $transferStep, onDismiss: {
            prefillToAccount = nil
            prefillAmount = nil
            prefillCurrency = nil
            Task {
                await loadData()
                // Promotions are applied asynchronously (~5-8s after deposit).
                // Reload again after 10s so the $2 bonus appears without manual pull-to-refresh.
                try? await Task.sleep(for: .seconds(10))
                await loadData()
            }
        }) { step in
            TransferFlowView(
                initialStep: step,
                txVM: txVM,
                prefilledToAccount: prefillToAccount,
                prefilledAmount: prefillAmount,
                prefilledCurrency: prefillCurrency
            )
        }
        .fullScreenCover(isPresented: $showQrPay, onDismiss: {
            Task {
                await loadData()
                try? await Task.sleep(for: .seconds(10))
                await loadData()
            }
        }) { QrPayFlowView() }
        .fullScreenCover(isPresented: $showAtmWithdraw, onDismiss: { Task { await loadData() } }) {
            AtmWithdrawView(accounts: accountVM.accounts)
        }
        .fullScreenCover(isPresented: $showLoans, onDismiss: { Task { await loadData() } }) {
            NavigationStack { LoansView() }
        }
        .fullScreenCover(isPresented: $showPromotions, onDismiss: {
            Task { await loadData() }
        }) {
            PromotionsView(onDepositTapped: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    transferStep = .amount(mode: .deposit)
                }
            })
        }
        .fullScreenCover(isPresented: $showMoreServices, onDismiss: {
            Task { await loadData() }
        }) {
            MoreServicesView(
                accounts: accountVM.accounts,
                onDeposit: {
                    showMoreServices = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        transferStep = .amount(mode: .deposit)
                    }
                }
            )
        }
        .titanToast(toast: $toast)
    }

    private func loadData() async {
        async let a: () = accountVM.loadAccounts()
        async let t: () = txVM.loadHistory()
        await a; await t
    }

    private func startRealTimeSync() {
        realTimeTimer?.cancel()
        realTimeTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { break }
                async let a: () = accountVM.loadAccounts(silent: true)
                async let t: () = txVM.loadHistory(silent: true)
                await a; await t
            }
        }
    }

    // =========================================================================
    // MARK: - ABA / ACLEDA Style Header
    // =========================================================================
    private var abaStyleHeader: some View {
        ZStack(alignment: .bottom) {
            // ── Angkor Wat photo background ───────────────────────────────────
            Rectangle()
                .ignoresSafeArea(edges: .top)
                .overlay(
                    ZStack {
                        Image("angkor_wat")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipped()

                        // Dark blue gradient overlay for readability — ABA style
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.18, blue: 0.58).opacity(0.90),
                                Color(red: 0.08, green: 0.32, blue: 0.78).opacity(0.80)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    }
                )

            VStack(spacing: 0) {
                // ── Row 1: App brand + icons ──────────────────────────────────
                HStack(alignment: .center) {
                    // Bank logo + name (like ABA "ABA Mobile")
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(.white.opacity(0.18))
                                .frame(width: 34, height: 34)
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TITAN")
                                .font(.system(size: 14, weight: .black))
                                .tracking(2)
                                .foregroundStyle(.white)
                            Text("Mobile Banking")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.70))
                        }
                    }

                    Spacer()

                    // QR scan icon (ABA has this prominently)
                    Button { showQrPay = true } label: {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }

                    // Notification bell
                    Button { onNotificationBellTapped?() } label: {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            if inAppNotif.unreadCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.95, green: 0.25, blue: 0.25))
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    Text(inAppNotif.unreadCount < 10 ? "\(inAppNotif.unreadCount)" : "9+")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 5, y: -4)
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // ── Row 2: Greeting + name + balance eye ─────────────────────
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(greetingText)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.72))
                        Text(authVM.userProfile?.firstName.map { "\($0) \(authVM.userProfile?.lastName ?? "")" }
                             ?? authVM.username)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Balance hide/show — ABA has this as an eye icon on the card
                    // We put it here in the header right side
                    Button { balanceHidden.toggle() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: balanceHidden ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 13))
                            Text(balanceHidden ? "Show" : "Hide")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 52) // room for card overlap
            }
        }
        .frame(minHeight: 160)
    }

    // =========================================================================
    // MARK: - Account Carousel
    // =========================================================================
    private var accountCarousel: some View {
        VStack(spacing: 10) {
            if accountVM.isLoading {
                SkeletonView().frame(height: 168).skeletonCorner(22).padding(.horizontal, 20)
            } else if accountVM.accounts.isEmpty {
                emptyAccountCard
            } else {
                TabView(selection: $selectedAccountIndex) {
                    ForEach(Array(accountVM.accounts.enumerated()), id: \.offset) { i, acct in
                        AccountHeroCard(
                            account: acct,
                            balanceHidden: balanceHidden,
                            onCopyAccount: { num in
                                toast = ToastMessage(icon: "doc.on.doc.fill", message: "Account \(num) copied!")
                            }
                        )
                        .padding(.horizontal, 16)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 178)

                if accountVM.accounts.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<accountVM.accounts.count, id: \.self) { i in
                            Capsule()
                                .fill(i == selectedAccountIndex
                                      ? Color.titanPrimary : Color.titanPrimary.opacity(0.20))
                                .frame(width: i == selectedAccountIndex ? 18 : 6, height: 6)
                                .animation(.spring(response: 0.28), value: selectedAccountIndex)
                        }
                    }
                }
            }
        }
    }

    private var emptyAccountCard: some View {
        TitanCard {
            VStack(spacing: 14) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.titanPrimary.opacity(0.35))
                Text("No accounts yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.titanSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
        }
        .padding(.horizontal, 20)
    }

    // =========================================================================
    // MARK: - Quick Action Grid  — Crystal Glassmorphism (matches Titan blue brand)
    // =========================================================================
    private var quickActionGrid: some View {

        struct Action {
            let icon: String
            let label: String
            let top: Color   // icon gradient top
            let bot: Color   // icon gradient bottom
            let action: () -> Void
        }

        let actions: [Action] = [
            Action(icon: "arrow.up.right",
                   label: "Transfer",
                   top: Color(red:0.22, green:0.48, blue:1.00),
                   bot: Color(red:0.08, green:0.24, blue:0.84),
                   action: {
                       prefillToAccount = nil
                       prefillAmount = nil
                       prefillCurrency = nil
                       transferStep = .selectRecipient
                   }),

            Action(icon: "qrcode.viewfinder",
                   label: "QR Pay",
                   top: Color(red:0.00, green:0.80, blue:0.62),
                   bot: Color(red:0.00, green:0.56, blue:0.44),
                   action: { showQrPay = true }),

            Action(icon: "tray.and.arrow.down.fill",
                   label: "Deposit",
                   top: Color(red:0.08, green:0.74, blue:0.54),
                   bot: Color(red:0.02, green:0.52, blue:0.38),
                   action: { transferStep = .amount(mode: .deposit) }),

            Action(icon: "banknote.fill",
                   label: "ATM Withdraw",
                   top: Color(red:0.94, green:0.26, blue:0.46),
                   bot: Color(red:0.76, green:0.08, blue:0.30),
                   action: { showAtmWithdraw = true }),

            Action(icon: "building.columns",
                   label: "Loans",
                   top: Color(red:0.06, green:0.58, blue:0.98),
                   bot: Color(red:0.02, green:0.36, blue:0.78),
                   action: { showLoans = true }),

            Action(icon: "gift.fill",
                   label: "Promotions",
                   top: Color(red:0.30, green:0.80, blue:0.44),
                   bot: Color(red:0.10, green:0.60, blue:0.30),
                   action: { showPromotions = true }),

            Action(icon: "square.grid.2x2",
                   label: "More",
                   top: Color(red:0.40, green:0.48, blue:0.66),
                   bot: Color(red:0.22, green:0.30, blue:0.50),
                   action: { showMoreServices = true }),
        ]

        return ZStack {
            // ── Crystal base — deep blue matching hero header ──────
            LinearGradient(
                colors: [
                    Color(red:0.06, green:0.16, blue:0.56),   // deep navy (hero match)
                    Color(red:0.12, green:0.28, blue:0.72),   // royal indigo
                    Color(red:0.22, green:0.44, blue:0.90),   // titan blue
                    Color(red:0.44, green:0.62, blue:0.98),   // bright periwinkle
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // ── Crystal iridescent shimmer layer ──────────────────
            LinearGradient(
                colors: [
                    Color(red:1.00, green:1.00, blue:1.00).opacity(0.12),
                    Color(red:0.60, green:0.80, blue:1.00).opacity(0.08),
                    Color(red:0.80, green:0.60, blue:1.00).opacity(0.06),
                    Color.clear,
                    Color(red:0.60, green:1.00, blue:0.90).opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // ── Frosted glass highlight — top edge ────────────────
            VStack {
                LinearGradient(
                    colors: [.white.opacity(0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                Spacer()
            }

            // ── Decorative crystal orbs ────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.14), .clear],
                        center: .center, startRadius: 0, endRadius: 70
                    )
                )
                .frame(width: 140).offset(x: -80, y: -30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red:0.60,green:0.80,blue:1.00).opacity(0.18), .clear],
                        center: .center, startRadius: 0, endRadius: 60
                    )
                )
                .frame(width: 120).offset(x: 110, y: 50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red:0.80,green:0.60,blue:1.00).opacity(0.12), .clear],
                        center: .center, startRadius: 0, endRadius: 50
                    )
                )
                .frame(width: 100).offset(x: 60, y: -20)

            // ── Content ────────────────────────────────────────────
            VStack(spacing: 0) {

                // Crystal header strip
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("សេវាកម្ម")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                        Text("Services")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // Frosted pill button
                    Button { showMoreServices = true } label: {
                        HStack(spacing: 3) {
                            Text("See all")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .background(
                            // inner shimmer
                            LinearGradient(
                                colors: [.white.opacity(0.20), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.50), .white.opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

                // Thin frosted divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.25), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.6)
                    .padding(.horizontal, 18)

                // Icon grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4),
                    spacing: 20
                ) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                        GradientActionCell(
                            icon: item.icon,
                            label: item.label,
                            topColor: item.top,
                            botColor: item.bot,
                            action: item.action
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        // Crystal border — light refraction effect
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.55),
                            .white.opacity(0.20),
                            Color(red:0.60,green:0.80,blue:1.00).opacity(0.30),
                            .white.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        // Layered shadow: brand blue glow + depth
        .shadow(color: Color(red:0.10,green:0.22,blue:0.78).opacity(0.45), radius: 24, x: 0, y: 10)
        .shadow(color: Color(red:0.10,green:0.22,blue:0.78).opacity(0.20), radius: 8,  x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    // =========================================================================
    // MARK: - Recent Transactions
    // =========================================================================
    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ប្រតិបត្តិការថ្មីៗ / Recent")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.titanDark)
                Spacer()
                NavigationLink(destination: TransactionsView()) {
                    HStack(spacing: 3) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.titanPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if txVM.isLoading {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in skeletonTxRow }
                }
                .background(Color.titanBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else if txVM.transactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.titanSecondary.opacity(0.35))
                    Text("No transactions yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.titanSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                let myNums = Set(accountVM.accounts.map { $0.accountNumber })
                VStack(spacing: 0) {
                    ForEach(Array(txVM.transactions.prefix(5).enumerated()), id: \.element.id) { i, tx in
                        Button {
                            Haptics.tap()
                            selectedTx = tx
                        } label: {
                            TxRow(tx: tx, myAccountNumbers: myNums, balanceHidden: balanceHidden)
                                .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if i < min(txVM.transactions.count, 5) - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color.titanBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal, 16)
            }
        }
    }

    private var skeletonTxRow: some View {
        HStack(spacing: 12) {
            SkeletonView().frame(width: 42, height: 42).skeletonCorner(21)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView().frame(width: 110, height: 11).skeletonCorner(4)
                SkeletonView().frame(width: 72, height: 9).skeletonCorner(4)
            }
            Spacer()
            SkeletonView().frame(width: 60, height: 13).skeletonCorner(4)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Helpers
    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "អរុណសួស្ដី · Good Morning ☀️"
        case 12..<17: return "ទិវាសួស្ដី · Good Afternoon 🌤"
        default:      return "សាយណ្ហសួស្ដី · Good Evening 🌙"
        }
    }
    private var avatarInitials: String {
        String((authVM.userProfile?.firstName ?? authVM.username).prefix(1)).uppercased()
    }
}

// =========================================================================
// MARK: - Gradient Action Cell  — Ultra-crisp Crystal Icon Style
// =========================================================================
struct GradientActionCell: View {
    let icon: String
    let label: String
    let topColor: Color
    let botColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            VStack(spacing: 7) {
                ZStack {
                    // Soft glow underlay
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(botColor.opacity(0.35))
                        .frame(width: 48, height: 48)
                        .blur(radius: 3)
                        .offset(y: 2)

                    // Main crisp gradient background
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [topColor, botColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    // Inner glass shine overlay
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.32), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 48, height: 48)

                    // Fine crystal border
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 48, height: 48)

                    // SF Symbol
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.20), radius: 1.5, x: 0, y: 1)
                }

                // Action Label
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .bouncyButton(scale: 0.92)
    }
}

// =========================================================================
// MARK: - ABA Action Cell  (kept for legacy + typealias compat)
// =========================================================================
struct ABAActionCell: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        GradientActionCell(
            icon: icon,
            label: label,
            topColor: color,
            botColor: color.opacity(0.75),
            action: action
        )
    }
}

// Backwards-compat aliases used by other views
typealias ActionChip  = ABAActionCell
typealias ServiceChip = ABAActionCell

// =========================================================================
// MARK: - Account Hero Card
// =========================================================================
struct AccountHeroCard: View {
    let account: AccountModel
    var balanceHidden: Bool = false
    var onCopyAccount: ((String) -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(cardGradient)
                .shadow(color: .black.opacity(0.20), radius: 16, y: 7)

            // Decorative blobs
            Circle().fill(.white.opacity(0.06)).frame(width: 150).offset(x: 195, y: -22)
            Circle().fill(.white.opacity(0.04)).frame(width: 90).offset(x: 235, y: 48)
            RoundedRectangle(cornerRadius: 40).fill(.white.opacity(0.04))
                .frame(width: 130, height: 130).rotationEffect(.degrees(28)).offset(x: 172, y: 35)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "creditcard.fill").font(.system(size: 10))
                        Text(account.accountType.capitalized)
                            .font(.system(size: 10, weight: .bold)).tracking(0.3)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())

                    Spacer()

                    Text(account.currency)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.white.opacity(0.16))
                        .clipShape(Capsule())
                }

                Spacer()

                Text("Available Balance")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, 4)

                ZStack(alignment: .leading) {
                    Text(account.balance, format: .currency(code: account.currency))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .blur(radius: balanceHidden ? 10 : 0)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: account.balance)

                    if balanceHidden {
                        Text("● ● ● ● ●")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer().frame(height: 12)

                Button {
                    UIPasteboard.general.string = account.accountNumber
                    Haptics.success()
                    onCopyAccount?(account.accountNumber)
                } label: {
                    HStack(spacing: 6) {
                        Text("•••• \(account.accountNumber.suffix(4))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .bouncyButton(scale: 0.94)
            }
            .padding(20)
        }
        .frame(height: 168)
    }

    private var cardGradient: LinearGradient {
        switch account.accountType.uppercased() {
        case "SAVINGS":
            return LinearGradient(
                colors: [Color(red:0.10,green:0.38,blue:0.85), Color(red:0.04,green:0.18,blue:0.58)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "CHECKING":
            return LinearGradient(
                colors: [Color(red:0.12,green:0.52,blue:0.72), Color(red:0.06,green:0.28,blue:0.52)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(
                colors: [Color(red:0.28,green:0.14,blue:0.70), Color(red:0.16,green:0.08,blue:0.52)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// =========================================================================
// MARK: - Transaction Row (Home compact)
// =========================================================================
struct TxRow: View {
    let tx: TransactionResponse
    var myAccountNumbers: Set<String> = []
    var balanceHidden: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.10)).frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(labelText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.titanDark)
                if let date = tx.timestamp {
                    Text(date, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.titanSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if balanceHidden {
                    Text("••••").font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.titanSecondary)
                } else {
                    Text((isDebit ? "−" : "+") + tx.amount.formatted(.currency(code: tx.currency)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isDebit ? Color.titanOutflow : Color.titanInflow)
                    Text(SmartCurrencyConverter.dualCurrencyBadge(amount: tx.amount, currentCurrency: tx.currency))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.titanSecondary.opacity(0.85))
                }
                Text(tx.status.lowercased())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.titanSecondary)
            }
        }
    }

    private var isDebit: Bool {
        let t = tx.type.uppercased()
        if t == "DEPOSIT" { return false }
        if t == "WITHDRAW" || t == "WITHDRAWAL" { return true }
        if t == "TRANSFER" {
            if let from = tx.fromAccountNumber, !myAccountNumbers.isEmpty { return myAccountNumbers.contains(from) }
            if let to   = tx.toAccountNumber,   !myAccountNumbers.isEmpty { return !myAccountNumbers.contains(to) }
            return true
        }
        return true
    }
    private var labelText: String {
        let t = tx.type.uppercased()
        if t == "TRANSFER" {
            return isDebit
                ? "Sent to ···\(tx.toAccountNumber?.suffix(4) ?? "---")"
                : "Received from ···\(tx.fromAccountNumber?.suffix(4) ?? "---")"
        }
        switch t {
        case "DEPOSIT": return "Deposit"
        case "WITHDRAW","WITHDRAWAL": return "Withdrawal"
        default: return tx.type.capitalized
        }
    }
    private var iconName: String {
        let t = tx.type.uppercased()
        if t == "TRANSFER" { return isDebit ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill" }
        switch t {
        case "DEPOSIT": return "arrow.down.circle.fill"
        case "WITHDRAW","WITHDRAWAL": return "arrow.up.circle.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    private var iconColor: Color {
        if isDebit { return .titanOutflow }
        return (tx.type.uppercased() == "DEPOSIT" || tx.type.uppercased() == "TRANSFER") ? .titanInflow : .titanAccent
    }
}

// MARK: - Curved Bottom Shape (kept for any other views that use it)
struct RoundedBottomShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 30))
        p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - 30),
                       control: CGPoint(x: rect.midX, y: rect.maxY + 20))
        p.closeSubpath()
        return p
    }
}
