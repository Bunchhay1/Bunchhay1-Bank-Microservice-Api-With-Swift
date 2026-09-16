import SwiftUI

/// Merchant federation UI — list + create matching MerchantFederationController.
struct MerchantCampaignsSection: View {
    @ObservedObject var vm: PromotionViewModel
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 12) {
            Text("GET /api/merchant/campaigns?tenantId=")
                .font(.caption)
                .foregroundStyle(Color.titanSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Tenant ID", text: $vm.merchantTenantId)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)

            TitanPrimaryButton(label: "Load campaigns", isLoading: vm.isMerchantLoading) {
                Task { await vm.loadMerchantCampaigns() }
            }

            if !vm.merchantCampaigns.isEmpty {
                VStack(spacing: 8) {
                    ForEach(vm.merchantCampaigns) { campaign in
                        merchantRow(campaign)
                    }
                }
            }

            DisclosureGroup("Create campaign", isExpanded: $showCreate) {
                createForm
            }

            if let msg = vm.merchantMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(Color.titanSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    private func merchantRow(_ campaign: MerchantCampaignModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(campaign.campaignName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.titanDark)
                Spacer()
                Text(campaign.active == true ? "ACTIVE" : "OFF")
                    .font(.caption2.bold())
                    .foregroundStyle(campaign.active == true ? Color.titanInflow : .secondary)
            }
            Text("\(campaign.merchantName) · tenant \(campaign.tenantId)")
                .font(.caption)
                .foregroundStyle(Color.titanSecondary)
            HStack {
                Text(campaign.totalBudget, format: .currency(code: "USD"))
                    .font(.caption.weight(.semibold))
                if let remaining = campaign.remainingBudget {
                    Text("left \(remaining, format: .currency(code: "USD"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var createForm: some View {
        VStack(spacing: 10) {
            TextField("Tenant ID", text: $vm.createTenantId)
                .textFieldStyle(.roundedBorder)
            TextField("Merchant name", text: $vm.createMerchantName)
                .textFieldStyle(.roundedBorder)
            TextField("Merchant account ID", text: $vm.createMerchantAccountId)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            TextField("Campaign name", text: $vm.createCampaignName)
                .textFieldStyle(.roundedBorder)
            TextField("Total budget (USD)", text: $vm.createTotalBudget)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
            TextField("Rule expression (optional)", text: $vm.createRuleExpression)
                .textFieldStyle(.roundedBorder)

            TitanPrimaryButton(label: "Create campaign", isLoading: vm.isCreatingMerchant) {
                Task { await vm.createMerchantCampaign() }
            }
        }
        .padding(.top, 8)
    }
}
