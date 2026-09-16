import SwiftUI

struct TransactionsView: View {
    var mode: TransactionMode = .transfer
    @StateObject private var vm = TransactionViewModel()
    @StateObject private var accountVM = AccountViewModel()
    @State private var transferStep: TransferStep? = nil
    @State private var selectedTx: TransactionResponse? = nil
    @State private var prefillToAccount: String? = nil
    @State private var prefillAmount: Double? = nil
    @State private var prefillCurrency: String? = nil

    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if vm.isLoading {
                        VStack(spacing: 14) {
                            ForEach(0..<6, id: \.self) { _ in skeletonRow }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    } else if vm.transactions.isEmpty {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "arrow.left.arrow.right",
                            description: Text("Your transaction history appears here")
                        )
                        .padding(.top, 60)
                    } else {
                        let myNumbers = Set(accountVM.accounts.map { $0.accountNumber })
                        ForEach(vm.transactions) { tx in
                            Button {
                                Haptics.tap()
                                selectedTx = tx
                            } label: {
                                TransactionRowView(tx: tx, myAccountNumbers: myNumbers)
                                    .padding(.horizontal, 20)
                            }
                            .bouncyButton(scale: 0.98)
                            Spacer().frame(height: 14)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.tap()
                    prefillToAccount = nil
                    prefillAmount = nil
                    prefillCurrency = nil
                    transferStep = (mode == .transfer) ? .selectRecipient : .amount(mode: mode)
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            async let txs: () = vm.loadHistory()
            async let accs: () = accountVM.loadAccounts()
            await txs; await accs
        }
        .refreshable {
            async let txs: () = vm.loadHistory()
            async let accs: () = accountVM.loadAccounts()
            await txs; await accs
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
        }) { step in
            TransferFlowView(
                initialStep: step,
                txVM: vm,
                prefilledToAccount: prefillToAccount,
                prefilledAmount: prefillAmount,
                prefilledCurrency: prefillCurrency
            )
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 12) {
            SkeletonView().frame(width: 40, height: 40).skeletonCorner(20)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView().frame(width: 110, height: 12).skeletonCorner(4)
                SkeletonView().frame(width: 80, height: 10).skeletonCorner(4)
            }
            Spacer()
            SkeletonView().frame(width: 64, height: 14).skeletonCorner(4)
        }
    }
}

// MARK: - Transaction Row (design-system version)
struct TransactionRowView: View {
    let tx: TransactionResponse
    var myAccountNumbers: Set<String> = []

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: txIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(txColor)
                .frame(width: 40, height: 40)
                .background(txColor.opacity(0.10))
                .clipShape(Circle())

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(displayLabel)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.titanDark)
                if let date = tx.timestamp {
                    Text(date, style: .date)
                        .font(.system(.caption2))
                        .foregroundStyle(Color.titanSecondary)
                }
            }

            Spacer()

            // Amount + dual equivalent + status
            VStack(alignment: .trailing, spacing: 2) {
                Text((isDebit ? "−" : "+") + tx.amount.formatted(.currency(code: tx.currency)))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(txColor)

                Text(SmartCurrencyConverter.dualCurrencyBadge(amount: tx.amount, currentCurrency: tx.currency))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.titanSecondary.opacity(0.85))

                Text(tx.status.lowercased())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.titanSecondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // ── Sent / Received logic ─────────────────────────────────────────────────

    private var isDebit: Bool {
        let type = tx.type.uppercased()
        if type == "DEPOSIT"                           { return false }
        if type == "WITHDRAW" || type == "WITHDRAWAL" { return true  }
        if type == "TRANSFER" || type == "PAYMENT" {
            if let from = tx.fromAccountNumber, !myAccountNumbers.isEmpty {
                return myAccountNumbers.contains(from)
            }
            if let to = tx.toAccountNumber, !myAccountNumbers.isEmpty {
                return !myAccountNumbers.contains(to)
            }
            return true
        }
        return true
    }

    private var displayLabel: String {
        let type = tx.type.uppercased()
        switch type {
        case "TRANSFER", "PAYMENT":
            if isDebit {
                let to = tx.toAccountNumber.map { "···" + $0.suffix(4) } ?? "account"
                return "Sent to \(to)"
            } else {
                let from = tx.fromAccountNumber.map { "···" + $0.suffix(4) } ?? "account"
                return "Received from \(from)"
            }
        case "DEPOSIT":               return "Deposit"
        case "WITHDRAW","WITHDRAWAL": return "Withdrawal"
        default:                      return tx.type.capitalized
        }
    }

    private var txIcon: String {
        let type = tx.type.uppercased()
        if type == "TRANSFER" || type == "PAYMENT" {
            return isDebit ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill"
        }
        switch type {
        case "DEPOSIT":               return "arrow.down.to.line.circle.fill"
        case "WITHDRAW","WITHDRAWAL": return "arrow.up.from.line.circle.fill"
        default:                      return "dollarsign.circle.fill"
        }
    }

    private var txColor: Color {
        if isDebit { return .titanOutflow }
        let type = tx.type.uppercased()
        if type == "DEPOSIT" || type == "TRANSFER" || type == "PAYMENT" { return .titanInflow }
        return .titanAccent
    }
}

// MARK: - Transaction Detail & Clean 1-Tap Pay Back Sheet
struct TransactionDetailSheet: View {
    let tx: TransactionResponse
    var myAccountNumbers: Set<String> = []
    let onTransferBack: (_ counterpartyAccount: String, _ amount: Double, _ currency: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var toast: ToastMessage? = nil

    private var isDebit: Bool {
        let type = tx.type.uppercased()
        if type == "DEPOSIT" { return false }
        if type == "WITHDRAW" || type == "WITHDRAWAL" { return true }
        if type == "TRANSFER" || type == "PAYMENT" {
            if let from = tx.fromAccountNumber, !myAccountNumbers.isEmpty {
                return myAccountNumbers.contains(from)
            }
            if let to = tx.toAccountNumber, !myAccountNumbers.isEmpty {
                return !myAccountNumbers.contains(to)
            }
            return true
        }
        return true
    }

    /// The counterparty account to transfer back / pay back to
    private var counterpartyAccount: String? {
        let type = tx.type.uppercased()
        if type == "TRANSFER" || type == "PAYMENT" {
            if isDebit {
                return tx.toAccountNumber
            } else {
                return tx.fromAccountNumber
            }
        }
        return nil
    }

    /// Original currency of the transaction
    private var originalCurrency: String {
        tx.currency.uppercased()
    }

    /// Opposite currency for smart conversion (USD <-> KHR)
    private var oppositeCurrency: String {
        originalCurrency == "USD" ? "KHR" : "USD"
    }

    /// Smart converted amount in the opposite currency
    private var convertedAmount: Double {
        SmartCurrencyConverter.convert(amount: tx.amount, from: originalCurrency, to: oppositeCurrency)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Header Hero Card ───────────────────────────────────
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill((isDebit ? Color.titanOutflow : Color.titanInflow).opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: isDebit ? "arrow.up.right" : "arrow.down.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(isDebit ? Color.titanOutflow : Color.titanInflow)
                            }
                            .padding(.top, 14)

                            // Main amount
                            Text((isDebit ? "−" : "+") + SmartCurrencyConverter.format(amount: tx.amount, currency: tx.currency))
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(Color.titanDark)

                            // Clean Dual-currency badge
                            Text(SmartCurrencyConverter.dualCurrencyBadge(amount: tx.amount, currentCurrency: tx.currency))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.titanPrimary.opacity(0.10))
                                .clipShape(Capsule())

                            HStack(spacing: 6) {
                                Circle().fill(Color.titanInflow).frame(width: 7, height: 7)
                                Text(tx.status.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.titanInflow)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.titanInflow.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
                        .padding(.horizontal, 18)

                        // ── Pay Back / Transfer Again Button ──────────────────
                        if let counter = counterpartyAccount, !counter.isEmpty {
                            Button {
                                Haptics.tap()
                                onTransferBack(counter, 0, originalCurrency)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isDebit ? "arrow.clockwise" : "arrow.uturn.backward")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.titanPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(Color.titanPrimary.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isDebit ? "Transfer Again" : "Pay Back")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.titanDark)
                                        Text("To account ···\(counter.suffix(4))")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.titanSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.titanSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
                            }
                            .bouncyButton(scale: 0.97)
                            .padding(.horizontal, 18)
                        }

                        // ── Details Table ─────────────────────────────────────
                        VStack(spacing: 0) {
                            if let counter = counterpartyAccount, !counter.isEmpty {
                                detailRow(
                                    title: isDebit ? "Recipient Account" : "Sender Account",
                                    value: counter,
                                    canCopy: true
                                )
                                Divider().padding(.horizontal, 16)
                            }

                            if let from = tx.fromAccountNumber, !from.isEmpty {
                                detailRow(title: "From Account", value: from, canCopy: true)
                                Divider().padding(.horizontal, 16)
                            }

                            detailRow(
                                title: "Equivalent",
                                value: SmartCurrencyConverter.format(amount: convertedAmount, currency: oppositeCurrency)
                            )
                            Divider().padding(.horizontal, 16)

                            if let date = tx.timestamp {
                                detailRow(title: "Date & Time", value: date.formatted(date: .abbreviated, time: .shortened))
                                Divider().padding(.horizontal, 16)
                            }

                            if let ref = tx.referenceNumber, !ref.isEmpty {
                                detailRow(title: "Reference No.", value: ref, canCopy: true)
                                Divider().padding(.horizontal, 16)
                            }

                            if let note = tx.note, !note.isEmpty {
                                detailRow(title: "Note / Description", value: note)
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
                        .padding(.horizontal, 18)

                        // ── Share Receipt ─────────────────────────────────────
                        ShareLink(
                            item: "Titan Bank Receipt\nRef: \(tx.referenceNumber ?? "N/A")\nAmount: \(SmartCurrencyConverter.format(amount: tx.amount, currency: tx.currency))\nDate: \(tx.timestamp?.formatted() ?? "")"
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Receipt")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.titanPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .bouncyButton(scale: 0.95)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .titanToast(toast: $toast)
        }
    }

    private func detailRow(title: String, value: String, canCopy: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.titanSecondary)
            Spacer()
            if canCopy {
                Button {
                    UIPasteboard.general.string = value
                    Haptics.success()
                    toast = ToastMessage(icon: "doc.on.doc.fill", message: "\(title) copied!")
                } label: {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.titanDark)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.titanPrimary)
                    }
                }
                .bouncyButton(scale: 0.94)
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.titanDark)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
