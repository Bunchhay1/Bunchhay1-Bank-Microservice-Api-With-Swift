import SwiftUI

struct PromotionsView: View {
    @StateObject private var vm = PromotionViewModel()
    @Environment(\.dismiss) private var dismiss

    var onDepositTapped: (() -> Void)? = nil

    @State private var showManualApply = false
    @State private var showQuests = false
    @State private var showReferrals = false
    @State private var showMerchants = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.secondarySystemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if vm.isLoading && vm.status == nil {
                            ProgressView("Loading campaign…")
                                .padding(.top, 40)
                        } else if let status = vm.status {
                            campaignHero(status)
                            detailsCard(status)
                            TitanPrimaryButton(label: "Deposit now", isLoading: false) {
                                dismiss()
                                onDepositTapped?()
                            }
                            .padding(.horizontal, 4)

                            DisclosureGroup("Manual apply (advanced)", isExpanded: $showManualApply) {
                                manualApplyForm
                            }
                            .padding(16)
                            .background(Color.titanBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if let err = vm.errorMessage {
                            ContentUnavailableView(
                                "Promotions unavailable",
                                systemImage: "gift",
                                description: Text(err + "\n\nIs titan-promotions-service running on :8083?")
                            )
                            .padding(.top, 40)
                        }

                        if let msg = vm.applyMessage {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundStyle(Color.titanInflow)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.titanInflow.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        promoExtrasSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Promotions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await vm.loadStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await vm.loadStatus() }
            .refreshable { await vm.loadStatus() }
        }
    }

    private var promoExtrasSection: some View {
        VStack(spacing: 12) {
            Text("More rewards")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.titanSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            DisclosureGroup("Quests", isExpanded: $showQuests) {
                questsForm
            }
            .padding(16)
            .background(Color.titanBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            DisclosureGroup("Referrals", isExpanded: $showReferrals) {
                referralsForm
            }
            .padding(16)
            .background(Color.titanBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            DisclosureGroup("Merchant campaigns", isExpanded: $showMerchants) {
                MerchantCampaignsSection(vm: vm)
            }
            .padding(16)
            .background(Color.titanBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func campaignHero(_ status: CampaignStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(status.active ? "ACTIVE" : (status.dbStatus ?? "INACTIVE"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(status.active ? Color.titanInflow : Color.orange)
                    .clipShape(Capsule())
            }

            Text(status.campaignCode ?? "Deposit Bonus")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(status.message ?? "Deposit to earn a bonus")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min deposit")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(status.minDeposit ?? 100, format: .currency(code: "USD"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonus")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(status.bonusAmount ?? 2, format: .currency(code: "USD"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.26, blue: 0.46),
                    Color(red: 0.76, green: 0.08, blue: 0.30)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailsCard(_ status: CampaignStatus) -> some View {
        VStack(spacing: 0) {
            detailRow("Window", status.withinWindow ? "Open" : "Closed")
            Divider()
            detailRow("Starts", status.startDate ?? "—")
            Divider()
            detailRow("Ends", status.endDate ?? "—")
            Divider()
            detailRow("Quota used", "\(status.quotaUsed ?? 0)")
        }
        .background(Color.titanBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.titanSecondary)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(Color.titanDark)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var manualApplyForm: some View {
        VStack(spacing: 12) {
            TextField("Transaction ID", text: $vm.applyTransactionId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            TextField("Deposit amount", text: $vm.applyAmount)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
            TextField("Account ID (metadata)", text: $vm.applyAccountId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            TextField("Account number", text: $vm.applyAccountNumber)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            if let err = vm.errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.titanOutflow)
            }

            TitanPrimaryButton(label: "Apply bonus", isLoading: vm.isApplying) {
                Task { await vm.applyBonus() }
            }
        }
        .padding(.top, 8)
    }

    private var questsForm: some View {
        VStack(spacing: 12) {
            Text("Matches titan-promotions QuestController (query params).")
                .font(.caption)
                .foregroundStyle(Color.titanSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Account ID", text: $vm.questAccountId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            TitanPrimaryButton(label: "Start quest", isLoading: vm.isQuestBusy) {
                Task { await vm.startQuest() }
            }

            TextField("Quest ID", text: $vm.questId)
                .textFieldStyle(.roundedBorder)

            if let state = vm.questState {
                Text("State: \(state)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.titanPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button("Progress") {
                    Task { await vm.progressQuest() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isQuestBusy)

                Button("Refresh status") {
                    Task { await vm.refreshQuestStatus() }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isQuestBusy)
            }

            if let msg = vm.questMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(Color.titanSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    private var referralsForm: some View {
        VStack(spacing: 12) {
            Text("POST /api/referrals/add?referrerId=&referredAccountId=")
                .font(.caption)
                .foregroundStyle(Color.titanSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Referrer account ID", text: $vm.referrerId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            TextField("Referred account ID", text: $vm.referredAccountId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            TitanPrimaryButton(label: "Add referral", isLoading: vm.isReferralBusy) {
                Task { await vm.addReferral() }
            }

            if let msg = vm.referralMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(Color.titanInflow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }
}
