import Foundation
import Combine

@MainActor
final class PromotionViewModel: ObservableObject {
    @Published var status: CampaignStatus?
    @Published var isLoading = false
    @Published var isApplying = false
    @Published var errorMessage: String?
    @Published var applyMessage: String?

    /// Manual apply fields
    @Published var applyTransactionId = ""
    @Published var applyAmount = ""
    @Published var applyAccountId = ""
    @Published var applyAccountNumber = ""

    // MARK: Quests
    @Published var questAccountId = ""
    @Published var questId = ""
    @Published var questState: String?
    @Published var isQuestBusy = false
    @Published var questMessage: String?

    // MARK: Referrals
    @Published var referrerId = ""
    @Published var referredAccountId = ""
    @Published var isReferralBusy = false
    @Published var referralMessage: String?

    // MARK: Merchant campaigns
    @Published var merchantTenantId = "titan"
    @Published var merchantCampaigns: [MerchantCampaignModel] = []
    @Published var isMerchantLoading = false
    @Published var merchantMessage: String?

    @Published var createTenantId = "titan"
    @Published var createMerchantName = ""
    @Published var createMerchantAccountId = ""
    @Published var createCampaignName = ""
    @Published var createTotalBudget = ""
    @Published var createRuleExpression = ""
    @Published var isCreatingMerchant = false

    func loadStatus() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            status = try await APIClient.shared.promotionsRequest(
                .depositCampaignStatus,
                responseType: CampaignStatus.self
            )
        } catch {
            errorMessage = error.localizedDescription
            status = nil
        }
    }

    func applyBonus() async {
        guard let amount = Double(applyAmount.trimmingCharacters(in: .whitespaces)),
              amount > 0,
              !applyTransactionId.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a valid transaction ID and deposit amount."
            return
        }

        isApplying = true
        errorMessage = nil
        applyMessage = nil
        defer { isApplying = false }

        let accountId = applyAccountId.trimmingCharacters(in: .whitespaces)
        var metadata: [String: String] = [:]
        if !accountId.isEmpty { metadata["accountId"] = accountId }

        let request = DepositPromotionApplyRequest(
            transactionId: applyTransactionId.trimmingCharacters(in: .whitespaces),
            type: "DEPOSIT",
            amount: amount,
            currency: "USD",
            correlationId: UUID().uuidString,
            username: nil,
            targetAccountNumber: applyAccountNumber.isEmpty ? nil : applyAccountNumber,
            metadata: metadata.isEmpty ? nil : metadata
        )

        do {
            let result = try await APIClient.shared.promotionsRequest(
                .applyDepositBonus(request),
                responseType: DepositBonusApplyResponse.self
            )
            applyMessage = result.message
                ?? (result.applied
                    ? String(format: "Bonus $%.2f applied", result.bonus ?? 0)
                    : "Bonus not applied")
            await loadStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Quests (QuestController)

    func startQuest() async {
        guard let accountId = Int(questAccountId.trimmingCharacters(in: .whitespaces)) else {
            questMessage = "Enter a valid account ID."
            return
        }
        isQuestBusy = true
        questMessage = nil
        defer { isQuestBusy = false }
        do {
            let result = try await APIClient.shared.promotionsRequest(
                .startQuest(accountId: accountId),
                responseType: QuestStartResponse.self
            )
            questId = result.questId
            questState = result.status
            questMessage = "Quest started: \(result.questId)"
        } catch {
            questMessage = error.localizedDescription
        }
    }

    func progressQuest() async {
        let id = questId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else {
            questMessage = "Enter or start a quest first."
            return
        }
        isQuestBusy = true
        questMessage = nil
        defer { isQuestBusy = false }
        do {
            let result = try await APIClient.shared.promotionsRequest(
                .questProgress(id),
                responseType: QuestProgressResponse.self
            )
            questState = result.currentState
            questMessage = result.success
                ? "Progressed to \(result.currentState)"
                : "Progress failed (state: \(result.currentState))"
        } catch {
            questMessage = error.localizedDescription
        }
    }

    func refreshQuestStatus() async {
        let id = questId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else {
            questMessage = "Enter a quest ID."
            return
        }
        isQuestBusy = true
        questMessage = nil
        defer { isQuestBusy = false }
        do {
            let result = try await APIClient.shared.promotionsRequest(
                .questStatus(id),
                responseType: QuestStatusResponse.self
            )
            questId = result.questId
            questState = result.state
            questMessage = "Status: \(result.state)"
        } catch {
            questMessage = error.localizedDescription
        }
    }

    // MARK: - Referrals (ReferralController)

    func addReferral() async {
        guard let referrer = Int(referrerId.trimmingCharacters(in: .whitespaces)),
              let referred = Int(referredAccountId.trimmingCharacters(in: .whitespaces)) else {
            referralMessage = "Enter valid referrer and referred account IDs."
            return
        }
        isReferralBusy = true
        referralMessage = nil
        defer { isReferralBusy = false }
        do {
            let result = try await APIClient.shared.promotionsRequest(
                .addReferral(referrerId: referrer, referredAccountId: referred),
                responseType: ReferralAddResponse.self
            )
            referralMessage = result.message
        } catch {
            referralMessage = error.localizedDescription
        }
    }

    // MARK: - Merchant campaigns (MerchantFederationController)

    func loadMerchantCampaigns() async {
        let tenant = merchantTenantId.trimmingCharacters(in: .whitespaces)
        guard !tenant.isEmpty else {
            merchantMessage = "Enter a tenant ID."
            return
        }
        isMerchantLoading = true
        merchantMessage = nil
        defer { isMerchantLoading = false }
        do {
            merchantCampaigns = try await APIClient.shared.promotionsRequest(
                .listMerchantCampaigns(tenantId: tenant),
                responseType: [MerchantCampaignModel].self
            )
            if merchantCampaigns.isEmpty {
                merchantMessage = "No active campaigns for tenant “\(tenant)”."
            }
        } catch {
            merchantMessage = error.localizedDescription
            merchantCampaigns = []
        }
    }

    func createMerchantCampaign() async {
        guard let accountId = Int(createMerchantAccountId.trimmingCharacters(in: .whitespaces)),
              let budget = Double(createTotalBudget.trimmingCharacters(in: .whitespaces)),
              budget > 0,
              !createMerchantName.trimmingCharacters(in: .whitespaces).isEmpty,
              !createCampaignName.trimmingCharacters(in: .whitespaces).isEmpty else {
            merchantMessage = "Fill merchant name, campaign name, account ID, and budget."
            return
        }

        isCreatingMerchant = true
        merchantMessage = nil
        defer { isCreatingMerchant = false }

        let now = Date()
        let end = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let rule = createRuleExpression.trimmingCharacters(in: .whitespaces)
        let request = MerchantCampaignCreateRequest(
            tenantId: createTenantId.trimmingCharacters(in: .whitespaces).isEmpty
                ? "titan" : createTenantId.trimmingCharacters(in: .whitespaces),
            merchantName: createMerchantName.trimmingCharacters(in: .whitespaces),
            merchantAccountId: accountId,
            campaignName: createCampaignName.trimmingCharacters(in: .whitespaces),
            totalBudget: budget,
            startDate: fmt.string(from: now),
            endDate: fmt.string(from: end),
            ruleExpression: rule.isEmpty ? nil : rule
        )

        do {
            let created = try await APIClient.shared.promotionsRequest(
                .createMerchantCampaign(request),
                responseType: MerchantCampaignModel.self
            )
            merchantMessage = "Created campaign #\(created.id): \(created.campaignName)"
            merchantTenantId = created.tenantId
            await loadMerchantCampaigns()
        } catch {
            merchantMessage = error.localizedDescription
        }
    }
}
