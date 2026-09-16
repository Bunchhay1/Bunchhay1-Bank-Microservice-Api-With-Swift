import SwiftUI

/// Canadia Bank–style “All Services” hub.
/// Layout: navy brand header → search → categorized 4-column icon grids.
/// Actions still open the same Titan API screens (logic unchanged).
struct MoreServicesView: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [AccountModel]
    var onDeposit: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var showInternational = false
    @State private var showScheduled = false
    @State private var showFixedDeposit = false
    @State private var showOTP = false
    @State private var showStatements = false
    @State private var showPromotions = false
    @State private var showAtmRedeem = false
    @State private var pressedId: String?

    // Canadia-inspired palette (navy + soft surfaces)
    private let canadiaNavy = Color(red: 0.02, green: 0.18, blue: 0.42)
    private let canadiaNavyMid = Color(red: 0.06, green: 0.32, blue: 0.68)
    private let pageBg = Color(red: 0.94, green: 0.96, blue: 0.98)

    private struct ServiceItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let top: Color
        let bot: Color
        let action: () -> Void
    }

    private struct ServiceSection: Identifiable {
        let id: String
        let title: String
        let khmer: String
        let items: [ServiceItem]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                pageBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, -18)
                        .zIndex(2)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(filteredSections) { section in
                                sectionCard(section)
                            }

                            if filteredSections.isEmpty {
                                emptySearch
                            }

                            footerNote
                                .padding(.bottom, 28)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showInternational) {
                InternationalTransferView(accounts: accounts)
            }
            .sheet(isPresented: $showScheduled) {
                ScheduledTransferView(accounts: accounts)
            }
            .sheet(isPresented: $showFixedDeposit) {
                FixedDepositView(accounts: accounts)
            }
            .sheet(isPresented: $showOTP) {
                OtpGenerateView()
            }
            .sheet(isPresented: $showStatements) {
                StatementDownloadView(accounts: accounts)
            }
            .fullScreenCover(isPresented: $showPromotions) {
                PromotionsView(onDepositTapped: {
                    showPromotions = false
                    dismiss()
                    onDeposit?()
                })
            }
            .sheet(isPresented: $showAtmRedeem) {
                AtmRedeemView()
            }
        }
    }

    // MARK: - Header (Canadia-style navy band)

    private var header: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [canadiaNavy, canadiaNavyMid, Color(red: 0.12, green: 0.42, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            // Soft light accents
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 130, y: -40)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 100, height: 100)
                .offset(x: -120, y: 20)

            VStack(spacing: 10) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.16))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("សេវាកម្មទាំងអស់")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All Services")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Transfer · Save · Rewards · Tools")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(12)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .frame(height: 150)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary)
            TextField("Search services…", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: - Sections data (Titan APIs)

    private var allSections: [ServiceSection] {
        [
            ServiceSection(
                id: "transfer",
                title: "Transfer & Payments",
                khmer: "ផ្ទេរប្រាក់",
                items: [
                    ServiceItem(
                        id: "intl",
                        icon: "globe.asia.australia.fill",
                        title: "International",
                        subtitle: "SWIFT / IBAN",
                        top: Color(red: 0.10, green: 0.38, blue: 0.85),
                        bot: Color(red: 0.04, green: 0.22, blue: 0.62),
                        action: { showInternational = true }
                    ),
                    ServiceItem(
                        id: "scheduled",
                        icon: "calendar.badge.clock",
                        title: "Scheduled",
                        subtitle: "Future payment",
                        top: Color(red: 0.94, green: 0.40, blue: 0.20),
                        bot: Color(red: 0.78, green: 0.22, blue: 0.10),
                        action: { showScheduled = true }
                    ),
                    ServiceItem(
                        id: "deposit",
                        icon: "tray.and.arrow.down.fill",
                        title: "Deposit",
                        subtitle: "Top up account",
                        top: Color(red: 0.08, green: 0.70, blue: 0.48),
                        bot: Color(red: 0.02, green: 0.48, blue: 0.34),
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDeposit?()
                            }
                        }
                    ),
                ]
            ),
            ServiceSection(
                id: "savings",
                title: "Savings & Statements",
                khmer: "សន្សំ & របាយការណ៍",
                items: [
                    ServiceItem(
                        id: "fd",
                        icon: "chart.pie.fill",
                        title: "Fixed Deposit",
                        subtitle: "6% p.a.",
                        top: Color(red: 0.16, green: 0.62, blue: 0.42),
                        bot: Color(red: 0.06, green: 0.42, blue: 0.28),
                        action: { showFixedDeposit = true }
                    ),
                    ServiceItem(
                        id: "stmt",
                        icon: "doc.text.fill",
                        title: "Statement",
                        subtitle: "PDF download",
                        top: Color(red: 0.18, green: 0.55, blue: 0.88),
                        bot: Color(red: 0.08, green: 0.36, blue: 0.68),
                        action: { showStatements = true }
                    ),
                ]
            ),
            ServiceSection(
                id: "rewards",
                title: "Rewards & Loyalty",
                khmer: "រង្វាន់",
                items: [
                    ServiceItem(
                        id: "promo",
                        icon: "gift.fill",
                        title: "Promotions",
                        subtitle: "Bonus · Quests",
                        top: Color(red: 0.90, green: 0.22, blue: 0.42),
                        bot: Color(red: 0.70, green: 0.08, blue: 0.28),
                        action: { showPromotions = true }
                    ),
                ]
            ),
            ServiceSection(
                id: "security",
                title: "Security",
                khmer: "សុវត្ថិភាព",
                items: [
                    ServiceItem(
                        id: "otp",
                        icon: "key.fill",
                        title: "OTP",
                        subtitle: "High-value code",
                        top: Color(red: 0.55, green: 0.22, blue: 0.88),
                        bot: Color(red: 0.36, green: 0.10, blue: 0.68),
                        action: { showOTP = true }
                    ),
                ]
            ),
            ServiceSection(
                id: "tools",
                title: "Tools",
                khmer: "ឧបករណ៍",
                items: [
                    ServiceItem(
                        id: "atm-redeem",
                        icon: "banknote.fill",
                        title: "ATM Redeem",
                        subtitle: "Terminal sim",
                        top: Color(red: 0.10, green: 0.68, blue: 0.72),
                        bot: Color(red: 0.04, green: 0.46, blue: 0.52),
                        action: { showAtmRedeem = true }
                    ),
                ]
            ),
        ]
    }

    private var filteredSections: [ServiceSection] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allSections }
        return allSections.compactMap { section in
            let items = section.items.filter {
                $0.title.lowercased().contains(q)
                    || $0.subtitle.lowercased().contains(q)
                    || section.title.lowercased().contains(q)
            }
            return items.isEmpty
                ? nil
                : ServiceSection(id: section.id, title: section.title, khmer: section.khmer, items: items)
        }
    }

    // MARK: - Section card

    private func sectionCard(_ section: ServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(canadiaNavy)
                    Text(section.khmer)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Text("\(section.items.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(canadiaNavyMid)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(canadiaNavyMid.opacity(0.10))
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 16
            ) {
                ForEach(section.items) { item in
                    serviceCell(item)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private func serviceCell(_ item: ServiceItem) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                pressedId = item.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                pressedId = nil
                item.action()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [item.top, item.bot],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: item.top.opacity(0.35), radius: 6, y: 3)

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(item.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(UIColor.label))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(pressedId == item.id ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityHint(item.subtitle)
    }

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No services found")
                .font(.headline)
            Text("Try another keyword")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var footerNote: some View {
        Text("Powered by Titan APIs · Connected to your Docker services")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Color.secondary.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

#Preview {
    MoreServicesView(accounts: [])
}
