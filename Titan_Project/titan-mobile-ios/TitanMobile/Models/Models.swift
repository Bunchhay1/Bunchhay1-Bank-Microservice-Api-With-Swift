import SwiftUI

// MARK: - User
struct BankUser {
    let name: String
    let greetingKhmer: String
    let greeting: String
    let emoji: String
    let accountType: String
    let accountNumber: String
    let balance: Double
    let currency: String

    static let sample = BankUser(
        name: "Leng Navat",
        greetingKhmer: "សាយណ្ណាសសុគ្គី",
        greeting: "Good Evening",
        emoji: "🌙",
        accountType: "Savings",
        accountNumber: "**** ****  5586",
        balance: 16_698.12,
        currency: "USD"
    )
}

// MARK: - Service Item
struct ServiceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String        // SF Symbol
    let iconColor: Color    // icon tint
    let bgGradient: [Color] // gradient stops for bg circle
    let tag: ServiceTag

    enum ServiceTag {
        case transfer, qrPay, receive, deposit, withdraw, loans, savings, more
    }

    // All 8 services — cute vivid palette
    static let all: [ServiceItem] = [
        .init(title: "Transfer",  icon: "arrow.up.circle.fill",
              iconColor: .white, bgGradient: [Color(hex:"#4F78FF"), Color(hex:"#2B55E0")], tag: .transfer),

        .init(title: "QR Pay",    icon: "qrcode.viewfinder",
              iconColor: .white, bgGradient: [Color(hex:"#00C48C"), Color(hex:"#00A876")], tag: .qrPay),

        .init(title: "Receive",   icon: "arrow.down.left.circle.fill",
              iconColor: .white, bgGradient: [Color(hex:"#A855F7"), Color(hex:"#8B31E0")], tag: .receive),

        .init(title: "Deposit",   icon: "tray.and.arrow.down.fill",
              iconColor: .white, bgGradient: [Color(hex:"#10B981"), Color(hex:"#059669")], tag: .deposit),

        .init(title: "Withdraw",  icon: "banknote.fill",
              iconColor: .white, bgGradient: [Color(hex:"#F43F5E"), Color(hex:"#DC2626")], tag: .withdraw),

        .init(title: "Loans",     icon: "building.columns.fill",
              iconColor: .white, bgGradient: [Color(hex:"#F97316"), Color(hex:"#EA6000")], tag: .loans),

        .init(title: "Savings",   icon: "chart.pie.fill",
              iconColor: .white, bgGradient: [Color(hex:"#EAB308"), Color(hex:"#D97706")], tag: .savings),

        .init(title: "More",      icon: "ellipsis.circle.fill",
              iconColor: .white, bgGradient: [Color(hex:"#64748B"), Color(hex:"#475569")], tag: .more),
    ]
}

// MARK: - Transaction
enum TransactionKind { case received, sent, payment }

struct Transaction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: Double
    let currency: String
    let kind: TransactionKind
    let success: Bool

    var displayAmount: String {
        let v = String(format: "%.2f", abs(amount))
        return kind == .received ? "+\(currency)$\(v)" : "-\(currency)$\(v)"
    }
    var amountColor: Color  { kind == .received ? .textPositive : .textNegative }
    var iconName: String    { kind == .received ? "arrow.down.left" : kind == .sent ? "arrow.up.right" : "creditcard.fill" }
    var iconBG: Color       { kind == .received ? Color.iconDeposit.opacity(0.15) : kind == .sent ? Color.iconWithdraw.opacity(0.15) : Color.iconLoans.opacity(0.15) }
    var iconFG: Color       { kind == .received ? .iconDeposit : kind == .sent ? .iconWithdraw : .iconLoans }

    static let samples: [Transaction] = [
        .init(title: "Received from ···3952", subtitle: "10 July 2026", amount: 40,    currency: "US", kind: .received, success: true),
        .init(title: "Received from ···3952", subtitle: "10 July 2026", amount: 50,    currency: "US", kind: .received, success: true),
        .init(title: "Sent to ···3952",        subtitle: "10 July 2026", amount: 15000, currency: "US", kind: .sent,     success: true),
        .init(title: "QR Payment",             subtitle: "09 July 2026", amount: 12.50, currency: "US", kind: .payment,  success: true),
        .init(title: "Loan Repayment",         subtitle: "08 July 2026", amount: 200,   currency: "US", kind: .sent,     success: true),
    ]
}

// MARK: - Tab
enum AppTab: Int, CaseIterable {
    case home, accounts, transfers, loans, more
    var title: String  { ["Home","Accounts","Transfers","Loans","More"][rawValue] }
    var icon: String   { ["house.fill","creditcard.fill","arrow.left.arrow.right.circle.fill","doc.text.fill","ellipsis"][rawValue] }
}
