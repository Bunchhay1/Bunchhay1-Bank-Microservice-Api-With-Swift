import SwiftUI

// MARK: - ATM Withdraw View
/// Full-screen sheet — 3 states:
///   1. Form   : pick account, amount (USD/KHR), PIN → generate code
///   2. Code   : 12-digit code card + countdown + instructions
///   3. Used   : success confirmation

struct AtmWithdrawView: View {

    let accounts: [AccountModel]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AtmViewModel()

    // form state
    @State private var selectedAccount: AccountModel?
    @State private var rawAmount   = ""
    @State private var pin         = ""
    @State private var pinVisible  = false
    @State private var showConfirm = false

    // countdown
    @State private var secondsLeft = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            atmGradient.ignoresSafeArea()

            if let code = vm.successCode {
                if code.status == "PENDING" {
                    codeView(code: code)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity))
                } else if code.status == "USED" {
                    successView(code: code)
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                formView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.successCode?.status)
        .onAppear { selectedAccount = accounts.first }
        .onDisappear { timerTask?.cancel() }
    }

    // =========================================================================
    // MARK: – 1. FORM
    // =========================================================================
    private var formView: some View {
        VStack(spacing: 0) {
            navBar(title: "ATM Withdraw") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Info banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.blue)
                        Text("Generate a 12-digit code and enter it at any Titan ATM — no card needed.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(red: 0.90, green: 0.95, blue: 1.00))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Account picker
                    formSection(label: "From Account", icon: "creditcard.fill") {
                        if accounts.isEmpty {
                            Text("No accounts available")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(accounts) { acct in
                                        AccountChip(account: acct, isSelected: selectedAccount?.id == acct.id)
                                            .onTapGesture { selectedAccount = acct }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    // Currency toggle
                    formSection(label: "Currency", icon: "dollarsign.circle.fill") {
                        CurrencyToggle(isUSD: $vm.isUSD)
                    }

                    // Amount
                    formSection(label: "Amount", icon: "banknote") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Text(vm.isUSD ? "$" : "៛")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.90))
                                    .frame(width: 28)
                                TextField(vm.isUSD ? "0.00" : "0", text: $rawAmount)
                                    .keyboardType(vm.isUSD ? .decimalPad : .numberPad)
                                    .font(.system(size: 28, weight: .semibold))
                            }
                            .padding()
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if let usd = amountUSD, usd > 0 {
                                HStack {
                                    Spacer()
                                    Text(vm.isUSD
                                         ? "≈ \(Int(usd * KHR_PER_USD)) ៛"
                                         : "≈ $\(String(format: "%.2f", usd))")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 8) {
                                ForEach([20.0, 50.0, 100.0, 200.0], id: \.self) { amt in
                                    quickChip(amt)
                                }
                                Spacer()
                            }
                        }
                    }

                    // PIN
                    formSection(label: "PIN", icon: "lock.fill") {
                        HStack {
                            Group {
                                if pinVisible {
                                    TextField("Enter PIN", text: $pin)
                                } else {
                                    SecureField("Enter PIN", text: $pin)
                                }
                            }
                            .keyboardType(.numberPad)
                            .font(.system(size: 16))

                            Button { pinVisible.toggle() } label: {
                                Image(systemName: pinVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let err = vm.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text(err).font(.system(size: 13)).foregroundStyle(.red)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Generate button
                    Button { showConfirm = true } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "lock.open.rotation")
                                Text("Generate ATM Code")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid
                            ? LinearGradient(
                                colors: [Color(red: 0.22, green: 0.48, blue: 1.00),
                                         Color(red: 0.08, green: 0.24, blue: 0.84)],
                                startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.25)],
                                startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isFormValid || vm.isLoading)
                }
                .padding(20)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog(
            "Confirm Withdrawal",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Generate Code") {
                Task {
                    await vm.generateCode(
                        accountNumber: selectedAccount?.accountNumber ?? "",
                        amountUSD: amountUSD ?? 0,
                        pin: pin
                    )
                    if vm.successCode != nil { startCountdown() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let usd = amountUSD {
                Text("Withdraw \(vm.displayAmount(usdAmount: usd)) from account ending \(selectedAccount?.accountNumber.suffix(4) ?? "----")?")
            }
        }
    }

    // =========================================================================
    // MARK: – 2. CODE DISPLAY  (matches screenshot exactly)
    // =========================================================================
    private func codeView(code: AtmCodeResponse) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            navBar(title: "ATM Code") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Amount header ──────────────────────────────────────
                    VStack(spacing: 6) {
                        Text(vm.displayAmount(usdAmount: code.amount))
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(.white)

                        Text(vm.isUSD
                             ? "≈ \(Int(code.amount * KHR_PER_USD)) ៛"
                             : "≈ $\(String(format: "%.2f", code.amount))")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.65))

                        Text("from \(code.accountNumber)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 4)

                    // ── 12-digit code card ─────────────────────────────────
                    VStack(spacing: 20) {
                        Text("YOUR ATM CODE")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.secondary)
                            .tracking(2)

                        // All 12 digits on one line: XXXX XXXX XXXX
                        Text(formatted(code.code))
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.08, green: 0.24, blue: 0.84))
                            .tracking(3)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        // Copy / Share buttons
                        HStack(spacing: 12) {
                            // Copy
                            Button {
                                UIPasteboard.general.string = code.code
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.90))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 11)
                                    .background(Color(red: 0.90, green: 0.95, blue: 1.00))
                                    .clipShape(RoundedRectangle(cornerRadius: 22))
                            }

                            // Share
                            ShareLink(item: "My Titan ATM code: \(formatted(code.code)) — \(vm.displayAmount(usdAmount: code.amount))") {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 11)
                                    .background(Color(red: 0.22, green: 0.48, blue: 1.00))
                                    .clipShape(RoundedRectangle(cornerRadius: 22))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.16), radius: 20, y: 8)
                    .padding(.horizontal, 20)

                    // ── Countdown row ──────────────────────────────────────
                    CountdownRing(secondsLeft: secondsLeft)
                        .padding(.horizontal, 20)

                    // ── Step instructions ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array([
                            "Go to any Titan ATM",
                            "Select  \"Cardless Withdrawal\"",
                            "Enter the 12-digit code above",
                            "Collect your cash — no card needed!"
                        ].enumerated()), id: \.offset) { i, text in
                            InstructionRow(number: i + 1, text: text)
                        }
                    }
                    .padding(18)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)

                    // Error
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                    }

                    // ── Cancel button ──────────────────────────────────────
                    Button {
                        Task {
                            await vm.cancelCode(code.code)
                            timerTask?.cancel()
                        }
                    } label: {
                        Text(vm.isLoading ? "Cancelling…" : "Cancel This Code")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.90))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20)
                    }
                    .disabled(vm.isLoading)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    // =========================================================================
    // MARK: – 3. SUCCESS
    // =========================================================================
    private func successView(code: AtmCodeResponse) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 66))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text("Withdrawal Successful!")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                Text(vm.displayAmount(usdAmount: code.amount))
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                Text(vm.isUSD
                     ? "≈ \(Int(code.amount * KHR_PER_USD)) ៛"
                     : "≈ $\(String(format: "%.2f", code.amount))")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                Text("from \(code.accountNumber)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)
            }
            Button {
                vm.reset()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.24, blue: 0.84))
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
    }

    // =========================================================================
    // MARK: – Helpers
    // =========================================================================

    private var atmGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.18, blue: 0.58),
                Color(red: 0.14, green: 0.28, blue: 0.74),
                Color(red: 0.20, green: 0.40, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var amountUSD: Double? {
        guard let v = Double(rawAmount), v > 0 else { return nil }
        return vm.toUSD(v)
    }

    private var isFormValid: Bool {
        guard let acc = selectedAccount, !acc.accountNumber.isEmpty,
              let usd = amountUSD, usd >= 1,
              pin.count >= 4 else { return false }
        return true
    }

    /// Returns group `index` (0, 1, 2) of the 12-digit code (4 digits each)
    private func codeGroup(_ code: String, index: Int) -> String {
        guard code.count == 12 else { return code }
        let start = code.index(code.startIndex, offsetBy: index * 4)
        let end   = code.index(start, offsetBy: 4)
        return String(code[start..<end])
    }

    /// "123456789012" → "1234 5678 9012"
    private func formatted(_ code: String) -> String {
        guard code.count == 12 else { return code }
        return "\(code.prefix(4)) \(code.dropFirst(4).prefix(4)) \(code.suffix(4))"
    }

    private func startCountdown() {
        timerTask?.cancel()
        secondsLeft = vm.secondsRemaining(from: vm.successCode?.expiresAt)
        timerTask = Task {
            while secondsLeft > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                secondsLeft = max(0, secondsLeft - 1)
            }
            if let c = vm.successCode?.code { await vm.refreshStatus(c) }
        }
    }

    // ── Nav bar ──────────────────────────────────────────────────────────────
    @ViewBuilder
    private func navBar(title: String, close: @escaping () -> Void) -> some View {
        ZStack {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                Spacer()
            }
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    // ── Form section wrapper ─────────────────────────────────────────────────
    @ViewBuilder
    private func formSection<C: View>(
        label: String,
        icon: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // ── Quick-amount chips ────────────────────────────────────────────────────
    private func quickChip(_ usd: Double) -> some View {
        Button {
            rawAmount = vm.isUSD
                ? String(format: "%.0f", usd)
                : String(format: "%.0f", usd * KHR_PER_USD)
        } label: {
            Text(vm.isUSD ? "$\(Int(usd))" : "\(Int(usd * KHR_PER_USD))៛")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.90))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.90, green: 0.95, blue: 1.00))
                .clipShape(Capsule())
        }
    }
}

// =============================================================================
// MARK: – Reusable Sub-views
// =============================================================================

struct CurrencyToggle: View {
    @Binding var isUSD: Bool

    var body: some View {
        HStack(spacing: 0) {
            pill("USD  $", selected: isUSD)  { isUSD = true  }
            pill("KHR  ៛", selected: !isUSD) { isUSD = false }
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func pill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    selected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.22, green: 0.48, blue: 1.00),
                                 Color(red: 0.08, green: 0.24, blue: 0.84)],
                        startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .animation(.easeInOut(duration: 0.18), value: selected)
        }
    }
}

struct AccountChip: View {
    let account: AccountModel
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(account.accountType)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text("••• \(account.accountNumber.suffix(4))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .primary)
            Text(account.currency)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .white.opacity(0.80) : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isSelected
            ? AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.22, green: 0.48, blue: 1.00),
                         Color(red: 0.08, green: 0.24, blue: 0.84)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(UIColor.tertiarySystemFill))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.clear : Color(UIColor.separator), lineWidth: 1)
        )
    }
}

struct CountdownRing: View {
    let secondsLeft: Int

    private var progress: Double { Double(secondsLeft) / 600.0 }  // 10 min total
    private var mins: Int        { secondsLeft / 60 }
    private var secs: Int        { secondsLeft % 60 }
    private var ringColor: Color {
        secondsLeft > 300 ? .green : secondsLeft > 120 ? .yellow : .red
    }

    var body: some View {
        HStack(spacing: 18) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.20), lineWidth: 5)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Image(systemName: "timer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Code expires in")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.70))
                Text(String(format: "%02d:%02d", mins, secs))
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(ringColor)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
    }
}
