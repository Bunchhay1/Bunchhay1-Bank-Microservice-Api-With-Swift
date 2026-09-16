import SwiftUI

// MARK: - Transfer Step Model
enum TransferStep: Identifiable {
    case selectRecipient
    case amount(mode: TransactionMode)
    case review(from: String, to: String, amount: Double, mode: TransactionMode, currency: String = "USD")

    var id: String {
        switch self {
        case .selectRecipient:    return "recipient"
        case .amount(let m):      return "amount-\(m)"
        case .review:             return "review"
        }
    }
}

// MARK: - Crystal colour helpers (local, no global pollution)
private extension Color {
    static let xBlue   = Color(red: 0.10, green: 0.30, blue: 0.90)
    static let xNavy   = Color(red: 0.06, green: 0.16, blue: 0.58)
    static let xIndigo = Color(red: 0.18, green: 0.36, blue: 0.82)
    static let xGlass  = Color.white.opacity(0.12)
    static let xBorder = Color.white.opacity(0.28)
}

// MARK: - Crystal background (shared by all steps)
struct CrystalBackground: View {
    var body: some View {
        ZStack {
            // Base gradient — matches hero header
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.14, blue: 0.54),
                    Color(red: 0.12, green: 0.26, blue: 0.72),
                    Color(red: 0.22, green: 0.44, blue: 0.90),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Iridescent shimmer
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color(red: 0.60, green: 0.80, blue: 1.00).opacity(0.07),
                    Color(red: 0.80, green: 0.60, blue: 1.00).opacity(0.05),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Crystal orbs
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 100))
                .frame(width: 200)
                .offset(x: -120, y: -280)

            Circle()
                .fill(RadialGradient(
                    colors: [Color(red:0.60,green:0.80,blue:1.00).opacity(0.16), .clear],
                    center: .center, startRadius: 0, endRadius: 80))
                .frame(width: 160)
                .offset(x: 140, y: 180)

            Circle()
                .fill(RadialGradient(
                    colors: [Color(red:0.70,green:0.50,blue:1.00).opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 140)
                .offset(x: 100, y: -100)

            // Bottom white sheet
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.96))
                    .frame(height: UIScreen.main.bounds.height * 0.68)
                    .shadow(color: Color.xNavy.opacity(0.25), radius: 24, x: 0, y: -8)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Glass card modifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.10))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.50), .white.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            )
            .shadow(color: Color.xNavy.opacity(0.20), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

// MARK: - Crystal step pill header
private func crystalStepHeader(index: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        // Step badge
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 26, height: 26)
                Text(index)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(subtitle.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.75))
        }
        Text(title)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
}

// MARK: - Crystal text field
struct CrystalField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isError: Bool = false
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isError ? Color.red.opacity(0.9) : .white.opacity(0.70))
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(UIColor.label))
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(UIColor.label))
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(isError ? Color.red.opacity(0.08) : Color(UIColor.systemBackground).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isError
                        ? AnyShapeStyle(Color.red.opacity(0.60))
                        : AnyShapeStyle(LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)),
                    lineWidth: 1.0)
        )
        .shadow(color: Color.xNavy.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Crystal primary button
struct CrystalButton: View {
    let label: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isEnabled
                    ? LinearGradient(
                        colors: [Color(red:0.22,green:0.48,blue:1.00),
                                 Color(red:0.08,green:0.24,blue:0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(
                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.30 : 0.10), lineWidth: 0.8)
            )
            .shadow(color: Color.xBlue.opacity(isEnabled ? 0.45 : 0.0), radius: 16, x: 0, y: 6)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Flow Container
struct TransferFlowView: View {
    var initialStep: TransferStep
    @ObservedObject var txVM: TransactionViewModel
    var prefilledToAccount: String? = nil
    var prefilledAmount: Double? = nil
    var prefilledCurrency: String? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var step: TransferStep
    @State private var fromAccount = ""
    @State private var toAccount   = ""
    @State private var enteredAmount: Double = 0
    @StateObject private var accountVM = AccountViewModel()

    init(
        initialStep: TransferStep,
        txVM: TransactionViewModel,
        prefilledToAccount: String? = nil,
        prefilledAmount: Double? = nil,
        prefilledCurrency: String? = nil
    ) {
        self.initialStep = initialStep
        self.txVM = txVM
        self.prefilledToAccount = prefilledToAccount
        self.prefilledAmount = prefilledAmount
        self.prefilledCurrency = prefilledCurrency
        _step = State(initialValue: initialStep)
        if let to = prefilledToAccount {
            _toAccount = State(initialValue: to)
        }
        if let amt = prefilledAmount {
            _enteredAmount = State(initialValue: amt)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CrystalBackground()

            Group {
                switch step {
                case .selectRecipient:
                    RecipientStepView(from: $fromAccount, to: $toAccount) {
                        step = .amount(mode: .transfer)
                    }
                case .amount(let mode):
                    AmountStepView(
                        mode: mode,
                        amount: $enteredAmount,
                        fromAccount: $fromAccount,
                        toAccount: $toAccount,
                        prefilledAmount: prefilledAmount,
                        prefilledCurrency: prefilledCurrency
                    ) { amount, currency in
                        switch mode {
                        case .transfer: step = .review(from: fromAccount, to: toAccount,   amount: amount, mode: mode, currency: currency)
                        case .deposit:  step = .review(from: "",          to: toAccount,   amount: amount, mode: mode, currency: currency)
                        case .withdraw: step = .review(from: fromAccount, to: "",          amount: amount, mode: mode, currency: currency)
                        }
                    }
                case .review(let from, let to, let amount, let mode, let currency):
                    ReviewStepView(from: from, to: to, amount: amount, mode: mode, currency: currency, txVM: txVM) {
                        dismiss()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)))
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: step.id)

            // Crystal close button
            FloatingBackButton(icon: "xmark") {
                dismiss()
            }
            .padding(.top, 56)
            .padding(.leading, 22)
        }
        .task {
            await accountVM.loadAccounts()
            if let prefCurr = prefilledCurrency?.uppercased(),
               let matching = accountVM.accounts.first(where: { $0.currency.uppercased() == prefCurr }) {
                fromAccount = matching.accountNumber
            } else if fromAccount.isEmpty, let first = accountVM.accounts.first {
                fromAccount = first.accountNumber
            }
            if toAccount.isEmpty, let prefill = prefilledToAccount {
                toAccount = prefill
            }
        }
    }
}

// MARK: - Step 1: Select Recipient
struct RecipientStepView: View {
    @Binding var from: String
    @Binding var to: String
    let onNext: () -> Void

    @StateObject private var accountVM = AccountViewModel()
    @State private var note = ""
    @State private var toError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Crystal header on blue zone
            crystalStepHeader(index: "1", title: "Transfer Money", subtitle: "Step 01")
                .padding(.horizontal, 28)
                .padding(.top, 68)
                .padding(.bottom, 26)

            // White sheet content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── FROM ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        crystalLabel(icon: "creditcard.fill", text: "FROM ACCOUNT")

                        if accountVM.isLoading {
                            SkeletonView().frame(height: 76).skeletonCorner(16)
                                .padding(.horizontal, 28)
                        } else if accountVM.accounts.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.titanSecondary)
                                Text("No accounts. Please create one first.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.titanSecondary)
                            }
                            .padding(.horizontal, 28)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(accountVM.accounts) { acc in
                                        CrystalAccountChip(
                                            account: acc,
                                            isSelected: from == acc.accountNumber
                                        ) { from = acc.accountNumber }
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                        }
                    }

                    // ── TO ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            crystalLabel(icon: "person.fill", text: "TO ACCOUNT")
                            Spacer()
                            if UIPasteboard.general.hasStrings {
                                Button {
                                    if let str = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                                        to = str
                                        toError = false
                                        Haptics.tap()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.titanPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.titanPrimary.opacity(0.10))
                                    .clipShape(Capsule())
                                    .padding(.trailing, 28)
                                }
                            }
                        }
                        CrystalField(
                            icon: "number",
                            placeholder: "Recipient account number",
                            text: $to,
                            isError: toError,
                            keyboardType: .numberPad
                        )
                        .padding(.horizontal, 28)
                        .onChange(of: to) { _, _ in toError = false }
                        if toError {
                            crystalError("Please enter a recipient account number")
                        }
                    }

                    // ── NOTE ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        crystalLabel(icon: "text.bubble", text: "NOTE (OPTIONAL)")
                        CrystalField(
                            icon: "pencil",
                            placeholder: "e.g. Rent, Gift, Lunch, Payback…",
                            text: $note
                        )
                    }
                    .padding(.horizontal, 28)

                    // ── Balance hint ──────────────────────────────
                    if let acc = accountVM.accounts.first(where: { $0.accountNumber == from }) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.xBlue.opacity(0.70))
                            Text("Available: \(acc.balance, format: .currency(code: acc.currency))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.titanSecondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 28)
                    }

                    Spacer().frame(height: 12)
                }
            }

            // Continue button
            CrystalButton(
                label: "Continue",
                isEnabled: !from.isEmpty
            ) {
                guard !to.trimmingCharacters(in: .whitespaces).isEmpty else {
                    toError = true; return
                }
                onNext()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .task { await accountVM.loadAccounts() }
    }
}

// MARK: - Crystal Account Chip
private struct CrystalAccountChip: View {
    let account: AccountModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? .white.opacity(0.80) : Color.titanSecondary)
                    Text(account.accountType.capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.titanSecondary)
                    Text("(\(account.currency.uppercased()))")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(isSelected ? .white : Color.titanPrimary)
                }
                Text("···· \(account.accountNumber.suffix(4))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : Color.titanDark)
                Text(account.balance, format: .currency(code: account.currency))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.90) : Color.titanSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color(red:0.22,green:0.48,blue:1.00),
                                 Color(red:0.08,green:0.24,blue:0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(
                        colors: [Color(UIColor.secondarySystemBackground),
                                 Color(UIColor.secondarySystemBackground)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.30) : Color.titanPrimary.opacity(0.15),
                        lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.xBlue.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared small helpers
private func crystalLabel(icon: String, text: String) -> some View {
    Label(text, systemImage: icon)
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(1.2)
        .foregroundStyle(Color.titanSecondary)
        .padding(.horizontal, 28)
}

private func crystalError(_ msg: String) -> some View {
    Label(msg, systemImage: "exclamationmark.circle.fill")
        .font(.system(size: 12))
        .foregroundStyle(Color.red.opacity(0.85))
        .padding(.horizontal, 28)
}

// MARK: - Step 2: Amount — Crystal Numpad & Account Selector with Smart Conversion
struct AmountStepView: View {
    let mode: TransactionMode
    @Binding var amount: Double
    @Binding var fromAccount: String
    @Binding var toAccount: String
    var prefilledAmount: Double? = nil
    var prefilledCurrency: String? = nil
    let onNext: (Double, String) -> Void

    @StateObject private var accountVM = AccountViewModel()
    @State private var display = "0"
    @State private var accountError = false
    @State private var amountError: String? = nil
    @State private var showCustomAccountInput = false
    @FocusState private var accountFocused: Bool

    private let keys = ["1","2","3","4","5","6","7","8","9","⌫","0","."]

    private var targetAccountNumber: String {
        mode == .deposit ? toAccount : fromAccount
    }

    private var selectedAccount: AccountModel? {
        accountVM.accounts.first { $0.accountNumber == targetAccountNumber }
    }

    private var activeCurrency: String {
        selectedAccount?.currency.uppercased() ?? (prefilledCurrency?.uppercased() ?? "USD")
    }

    private var oppositeCurrency: String {
        activeCurrency == "USD" ? "KHR" : "USD"
    }

    /// Clean quick amounts: USD has 5, 10, 100; KHR has 20K, 40K, 400K
    private var quickAmounts: [Double] {
        if activeCurrency == "KHR" {
            return [20_000, 40_000, 400_000]
        } else {
            return [5, 10, 100]
        }
    }

    private func formatQuickAmountChip(_ val: Double) -> String {
        if activeCurrency == "KHR" {
            if val >= 1_000_000 {
                return "+\(Int(val / 1_000_000))M ៛"
            } else if val >= 1_000 {
                return "+\(Int(val / 1_000))K ៛"
            } else {
                return "+\(Int(val)) ៛"
            }
        } else {
            return "+\(Int(val))$"
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header on crystal zone
            crystalStepHeader(index: "2", title: modeTitle, subtitle: "Step 02")
                .padding(.horizontal, 28)
                .padding(.top, 68)
                .padding(.bottom, 12)

            // White card — account selector + amount display + quick chips + numpad
            VStack(spacing: 0) {

                // ── Account Selector ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        crystalLabel(
                            icon: mode == .deposit ? "tray.and.arrow.down.fill" : "creditcard.fill",
                            text: mode == .deposit ? "DEPOSIT TO ACCOUNT" : "PAY FROM ACCOUNT"
                        )
                        Spacer()
                        if let acc = selectedAccount {
                            Text(mode == .deposit
                                 ? "Bal: \(acc.balance, format: .currency(code: acc.currency))"
                                 : "Avail: \(acc.balance, format: .currency(code: acc.currency))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanPrimary)
                                .padding(.trailing, 28)
                        }
                    }

                    if accountVM.isLoading {
                        SkeletonView().frame(height: 54).skeletonCorner(12)
                            .padding(.horizontal, 28)
                    } else if !accountVM.accounts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(accountVM.accounts) { acc in
                                    let isSelected = targetAccountNumber == acc.accountNumber
                                    Button {
                                        Haptics.tap()
                                        let prevCurrency = activeCurrency
                                        let newCurrency = acc.currency.uppercased()

                                        if mode == .deposit {
                                            toAccount = acc.accountNumber
                                        } else {
                                            fromAccount = acc.accountNumber
                                        }

                                        // Auto-convert amount between USD and KHR on account switch (e.g. 5$ USD -> 20,500 KHR)
                                        if prevCurrency != newCurrency, let currentVal = Double(display), currentVal > 0 {
                                            let converted = SmartCurrencyConverter.convert(amount: currentVal, from: prevCurrency, to: newCurrency)
                                            if newCurrency == "KHR" {
                                                display = "\(Int(converted.rounded()))"
                                            } else {
                                                display = converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.2f", converted)
                                            }
                                        }

                                        accountError = false
                                        validateAmount()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(acc.accountType.capitalized)
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                Text("(\(acc.currency.uppercased()))")
                                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.titanPrimary)
                                            }
                                            Text("···\(acc.accountNumber.suffix(4)) · \(acc.balance, format: .currency(code: acc.currency))")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color.titanPrimary, Color.titanPrimaryDark],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyShapeStyle(Color(UIColor.secondarySystemBackground))
                                        )
                                        .foregroundStyle(isSelected ? .white : Color.titanDark)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .bouncyButton(scale: 0.95)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
                .padding(.top, 16)

                // ── Recipient Badge (transfer only) ───────────────────────────
                if mode == .transfer && !toAccount.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.titanPrimary)
                        Text("Sending to ···\(toAccount.suffix(4))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.titanSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.titanPrimary.opacity(0.08))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }

                Spacer()

                // ── Amount Display & Live Dual-Currency Converter ─────────────
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("AMOUNT")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Color.titanSecondary)

                        Text("• \(activeCurrency)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.titanPrimary)
                    }

                    Text(formattedDisplay)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            amountError != nil
                                ? AnyShapeStyle(Color.red)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color(red:0.22,green:0.48,blue:1.00),
                                             Color(red:0.08,green:0.24,blue:0.82)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .minimumScaleFactor(0.35)
                        .lineLimit(1)
                        .padding(.horizontal, 28)
                        .animation(.spring(response: 0.25), value: display)

                    // ── Real-Time Dual Currency Live Badge & Switcher ─────────
                    if let val = Double(display), val > 0 {
                        let converted = SmartCurrencyConverter.convert(amount: val, from: activeCurrency, to: oppositeCurrency)
                        let formattedOpposite = SmartCurrencyConverter.format(amount: converted, currency: oppositeCurrency)

                        HStack(spacing: 8) {
                            Text("≈ \(formattedOpposite)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.titanPrimary.opacity(0.10))
                                .clipShape(Capsule())

                            // Currency Switcher Button (e.g. 5$ USD <-> 20,500 KHR)
                            if let matchingOtherAccount = accountVM.accounts.first(where: { $0.currency.uppercased() == oppositeCurrency }) {
                                Button {
                                    Haptics.medium()
                                    if mode == .deposit {
                                        toAccount = matchingOtherAccount.accountNumber
                                    } else {
                                        fromAccount = matchingOtherAccount.accountNumber
                                    }
                                    if oppositeCurrency == "KHR" {
                                        display = "\(Int(converted.rounded()))"
                                    } else {
                                        display = converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.2f", converted)
                                    }
                                    validateAmount()
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Switch to \(oppositeCurrency)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.titanPrimary, Color.titanNavy],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                }
                                .bouncyButton(scale: 0.94)
                            }
                        }
                        .padding(.top, 2)
                    }

                    if let err = amountError {
                        Text(err)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 2)
                    } else {
                        Text("Max: \(kMaxTransferAmount.formatted(.currency(code: activeCurrency)))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.titanSecondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                // ── Clean Quick Preset Chips ──────────────────────────────────
                HStack(spacing: 10) {
                    ForEach(quickAmounts, id: \.self) { val in
                        Button {
                            Haptics.tap()
                            let cur = Double(display) ?? 0
                            display = String(format: activeCurrency == "KHR" ? "%.0f" : "%.2f", cur + val)
                            validateAmount()
                        } label: {
                            Text(formatQuickAmountChip(val))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.titanPrimary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .bouncyButton(scale: 0.94)
                    }

                    if mode != .deposit, let acc = selectedAccount, acc.balance > 0 {
                        Button {
                            Haptics.medium()
                            display = String(format: activeCurrency == "KHR" ? "%.0f" : "%.2f", acc.balance)
                            validateAmount()
                        } label: {
                            Text("Max")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanInflow)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.titanInflow.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .bouncyButton(scale: 0.94)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 6)

                // Thin divider
                Rectangle()
                    .fill(Color(UIColor.separator).opacity(0.35))
                    .frame(height: 0.5)
                    .padding(.horizontal, 28)

                // Crystal numpad
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3),
                    spacing: 0
                ) {
                    ForEach(keys, id: \.self) { key in
                        crystalNumKey(key)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)

                // Confirm button
                CrystalButton(
                    label: "Continue",
                    isEnabled: isContinueEnabled
                ) {
                    accountFocused = false
                    if targetAccountNumber.trimmingCharacters(in: .whitespaces).isEmpty {
                        accountError = true; return
                    }
                    guard let v = Double(display), v > 0 else { return }
                    if mode == .transfer, v >= kMaxTransferAmount {
                        amountError = "Exceeds max transfer limit of \(kMaxTransferAmount.formatted(.currency(code: activeCurrency)))"
                        return
                    }
                    if mode != .deposit, let acc = selectedAccount, v > acc.balance {
                        amountError = "Exceeds available balance (\(acc.balance.formatted(.currency(code: acc.currency))))"
                        return
                    }
                    amountError = nil
                    amount = v
                    onNext(v, activeCurrency)
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.xNavy.opacity(0.18), radius: 20, x: 0, y: -6)
        }
        .onAppear {
            if amount > 0 {
                display = String(format: activeCurrency == "KHR" ? "%.0f" : "%.2f", amount)
            }
        }
        .task {
            await accountVM.loadAccounts()
            if let prefCurr = prefilledCurrency?.uppercased(),
               let matching = accountVM.accounts.first(where: { $0.currency.uppercased() == prefCurr }) {
                if mode == .deposit {
                    toAccount = matching.accountNumber
                } else {
                    fromAccount = matching.accountNumber
                }
            } else {
                if mode == .deposit {
                    if toAccount.isEmpty, let first = accountVM.accounts.first {
                        toAccount = first.accountNumber
                    }
                } else {
                    if fromAccount.isEmpty, let first = accountVM.accounts.first {
                        fromAccount = first.accountNumber
                    }
                }
            }
            validateAmount()
        }
    }

    private var isContinueEnabled: Bool {
        guard let v = Double(display), v > 0 else { return false }
        if targetAccountNumber.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if mode != .deposit, let acc = selectedAccount, v > acc.balance { return false }
        return true
    }

    private func validateAmount() {
        guard let v = Double(display) else {
            amountError = nil
            return
        }
        if mode != .deposit, let acc = selectedAccount, v > acc.balance {
            amountError = "Exceeds available balance (\(acc.balance.formatted(.currency(code: acc.currency))))"
        } else if mode == .transfer && v >= kMaxTransferAmount {
            amountError = "Exceeds max transfer limit"
        } else {
            amountError = nil
        }
    }

    // MARK: Crystal numpad key
    private func crystalNumKey(_ key: String) -> some View {
        Button { tap(key) } label: {
            ZStack {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.titanSecondary)
                } else {
                    Text(key)
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.titanDark)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            display = display.count > 1 ? String(display.dropLast()) : "0"
        case ".":
            if activeCurrency == "KHR" {
                return
            }
            if !display.contains(".") { display += "." }
        default:
            if display == "0" { display = key } else { display += key }
        }
        amountError = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var formattedDisplay: String {
        if let v = Double(display) {
            return SmartCurrencyConverter.format(amount: v, currency: activeCurrency)
        }
        return (activeCurrency == "KHR" ? "៛ " : "$") + display
    }

    private var modeTitle: String {
        switch mode {
        case .transfer: return "Enter Amount"
        case .deposit:  return "Deposit Funds"
        case .withdraw: return "Withdraw Funds"
        }
    }
}

// MARK: - Step 3: Review & Crystal Swipe Confirm
struct ReviewStepView: View {
    let from: String
    let to: String
    let amount: Double
    let mode: TransactionMode
    var currency: String = "USD"
    @ObservedObject var txVM: TransactionViewModel
    let onDone: () -> Void

    @State private var pin = ""
    @State private var dragOffset: CGFloat = 0
    @State private var confirmed = false
    @State private var showSuccess = false

    private let trackWidth: CGFloat = UIScreen.main.bounds.width - 56
    private let thumbSize: CGFloat  = 58

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header on crystal zone
            crystalStepHeader(index: "3", title: "Review & Confirm", subtitle: "Step 03")
                .padding(.horizontal, 28)
                .padding(.top, 68)
                .padding(.bottom, 24)

            // White sheet
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Crystal summary card ──────────────────────
                    VStack(spacing: 0) {
                        // Amount hero
                        VStack(spacing: 4) {
                            Text("TOTAL AMOUNT")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(Color.titanSecondary)

                            Text(SmartCurrencyConverter.format(amount: amount, currency: currency))
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red:0.22,green:0.48,blue:1.00),
                                                 Color(red:0.08,green:0.24,blue:0.82)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                )

                            // Dual currency equivalent
                            Text(SmartCurrencyConverter.dualCurrencyBadge(amount: amount, currentCurrency: currency))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.titanPrimary.opacity(0.10))
                                .clipShape(Capsule())
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        // Detail rows
                        VStack(spacing: 0) {
                            reviewRow(
                                icon: "arrow.left.arrow.right.circle.fill",
                                label: "Type",
                                value: modeLabel,
                                valueColor: Color.titanPrimary
                            )
                            rowDivider()
                            reviewRow(
                                icon: "banknote.fill",
                                label: "Currency",
                                value: currency.uppercased() == "KHR" ? "KHR (Cambodian Riel)" : "USD (US Dollar)",
                                valueColor: Color.titanPrimary
                            )
                            rowDivider()
                            if !from.isEmpty {
                                reviewRow(icon: "arrow.up.right.circle.fill",
                                          label: "From", value: maskedAccount(from),
                                          valueColor: Color.titanDark)
                                rowDivider()
                            }
                            if !to.isEmpty {
                                reviewRow(icon: "arrow.down.left.circle.fill",
                                          label: "To", value: maskedAccount(to),
                                          valueColor: Color.titanDark)
                                rowDivider()
                            }
                            reviewRow(
                                icon: "checkmark.circle.fill",
                                label: "Fee",
                                value: "Free",
                                valueColor: Color.titanInflow
                            )
                            rowDivider()
                            reviewRow(icon: "checkmark.shield.fill",
                                      label: "Status", value: "Pending PIN confirmation",
                                      valueColor: Color.orange)
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 28)

                    // ── PIN entry ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        crystalLabel(icon: "lock.fill", text: "ENTER PIN TO CONFIRM")
                        CrystalField(
                            icon: "lock.fill",
                            placeholder: "4–6 digit PIN",
                            text: $pin,
                            isSecure: true,
                            keyboardType: .numberPad
                        )
                    }
                    .padding(.horizontal, 28)

                    // ── Error / loading / success ─────────────────
                    if let err = txVM.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red)
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.red.opacity(0.90))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 28)
                    }

                    if txVM.isLoading {
                        HStack(spacing: 10) {
                            ProgressView().tint(Color.titanPrimary)
                            Text("Processing transaction…")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.titanSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if showSuccess {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.titanInflow)
                            Text("Transaction Successful!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.titanInflow)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }

                    Spacer().frame(height: 16)
                }
            }

            // ── Crystal swipe-to-confirm line ─────────────────────
            VStack(spacing: 10) {
                swipeTrack
                Text(pin.count >= 4
                     ? (confirmed ? "✓ Confirmed" : "Slide to confirm →")
                     : (pin.isEmpty ? "Enter your PIN to confirm" : "Enter at least 4 digits"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(pin.count >= 4 ? Color.titanPrimary : Color.titanSecondary)
                    .animation(.easeInOut, value: pin.count)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: Swipe track
    private var swipeTrack: some View {
        ZStack(alignment: .leading) {
            // Track base
            RoundedRectangle(cornerRadius: thumbSize / 2)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: trackWidth, height: thumbSize)
                .overlay(
                    RoundedRectangle(cornerRadius: thumbSize / 2)
                        .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.8)
                )

            // Fill bar
            RoundedRectangle(cornerRadius: thumbSize / 2)
                .fill(
                    LinearGradient(
                        colors: confirmed
                            ? [Color.titanInflow, Color.titanInflow.opacity(0.80)]
                            : [Color(red:0.22,green:0.48,blue:1.00).opacity(0.25),
                               Color(red:0.08,green:0.24,blue:0.82).opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: max(thumbSize, dragOffset + thumbSize), height: thumbSize)
                .animation(.spring(response: 0.3), value: confirmed)

            // Thumb
            ZStack {
                Circle()
                    .fill(
                        pin.count >= 4
                            ? LinearGradient(
                                colors: confirmed
                                    ? [Color.titanInflow, Color.titanInflow.opacity(0.80)]
                                    : [Color(red:0.22,green:0.48,blue:1.00),
                                       Color(red:0.08,green:0.24,blue:0.82)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: pin.count >= 4 ? Color.xBlue.opacity(0.45) : .clear,
                            radius: 10, x: 0, y: 4)

                // Glass shine on thumb
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .topLeading, endPoint: .center))
                    .frame(width: thumbSize, height: thumbSize)

                Image(systemName: confirmed ? "checkmark" : "chevron.right.2")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { v in
                        guard pin.count >= 4, !confirmed else { return }
                        let maxOffset = trackWidth - thumbSize
                        dragOffset = min(maxOffset, max(0, v.translation.width))
                        if dragOffset > 0 { txVM.errorMessage = nil }
                    }
                    .onEnded { _ in
                        guard pin.count >= 4 else {
                            withAnimation(.spring()) { dragOffset = 0 }
                            txVM.errorMessage = "Please enter your PIN first."
                            return
                        }
                        let maxOffset = trackWidth - thumbSize
                        if dragOffset > maxOffset * 0.78 {
                            dragOffset = maxOffset
                            confirmed = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            submit()
                        } else {
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
        }
        .disabled(confirmed || txVM.isLoading)
    }

    // MARK: Review row
    private func reviewRow(icon: String, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.titanPrimary.opacity(0.65))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.titanSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    private var modeLabel: String {
        switch mode {
        case .transfer: return "Transfer / Pay Back"
        case .deposit:  return "Deposit"
        case .withdraw: return "Withdraw"
        }
    }

    private func maskedAccount(_ acc: String) -> String {
        acc.count > 4 ? "···· \(acc.suffix(4))" : acc
    }

    private func submit() {
        Task {
            let ok: Bool
            switch mode {
            case .transfer: ok = await txVM.transfer(from: from, to: to,  amount: amount, note: "Transfer / Payback", pin: pin, currency: currency)
            case .deposit:  ok = await txVM.deposit(to: to,               amount: amount, pin: pin)
            case .withdraw: ok = await txVM.withdraw(from: from,           amount: amount, pin: pin)
            }
            if ok {
                showSuccess = true
                try? await Task.sleep(for: .seconds(1.4))
                onDone()
            } else {
                withAnimation(.spring()) { dragOffset = 0; confirmed = false }
            }
        }
    }
}
