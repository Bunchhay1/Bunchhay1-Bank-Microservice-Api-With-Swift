import SwiftUI

// MARK: - Recent Transactions Section
struct RecentTransactionsView: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ប្រតិបត្តិការថ្មីៗ")
                        .font(AppFont.regular(11))
                        .foregroundColor(.textSecondary)
                    Text("Recent")
                        .font(AppFont.bold(18))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Button {} label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(AppFont.medium(13))
                            .foregroundColor(.titanBlue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.titanBlue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.titanBlueSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { i, tx in
                    TransactionRow(transaction: tx)
                    if i < transactions.count - 1 {
                        Divider().padding(.leading, 72).padding(.trailing, 20)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.cardBG)
                .cardShadow()
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(transaction.iconBG)
                    .frame(width: 46, height: 46)
                Image(systemName: transaction.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(transaction.iconFG)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(AppFont.semibold(14))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.subtitle)
                        .font(AppFont.regular(12))
                        .foregroundColor(.textSecondary)
                    if transaction.success {
                        Text("success")
                            .font(AppFont.medium(10))
                            .foregroundColor(.textPositive)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.textPositive.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Text(transaction.displayAmount)
                .font(AppFont.bold(14))
                .foregroundColor(transaction.amountColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

#Preview {
    ZStack {
        Color.appBG.ignoresSafeArea()
        RecentTransactionsView(transactions: Transaction.samples)
    }
}
