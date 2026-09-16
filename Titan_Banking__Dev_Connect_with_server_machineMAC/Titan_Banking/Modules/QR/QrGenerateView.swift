import SwiftUI
import Combine

// MARK: - QrGenerateView
struct QrGenerateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var qrVM      = QrViewModel()
    @StateObject private var accountVM = AccountViewModel()

    @State private var selectedAccount = ""
    @State private var amountText      = ""
    @State private var note            = ""
    @State private var ttl             = 15
    @State private var showCancelAlert = false

    var body: some View {
        ZStack {
            Color.titanBackground.ignoresSafeArea()

            if let qr = qrVM.activeQr, let b64 = qr.qrImageBase64 {
                ActiveQrView(
                    qr: qr,
                    b64: b64,
                    qrVM: qrVM,
                    showCancelAlert: $showCancelAlert,
                    onDismiss: { dismiss() }
                )
            } else {
                GenerateFormView(
                    accountVM:       accountVM,
                    qrVM:            qrVM,
                    selectedAccount: $selectedAccount,
                    amountText:      $amountText,
                    note:            $note,
                    ttl:             $ttl,
                    onDismiss:       { dismiss() }
                )
            }
        }
        .task { await accountVM.loadAccounts() }
        .alert("Cancel QR Code?", isPresented: $showCancelAlert) {
            Button("Cancel QR", role: .destructive) {
                guard let code = qrVM.activeQr?.qrCode else { return }
                Task { await qrVM.cancelQr(qrCode: code) }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This QR code will be deactivated and cannot be used.")
        }
    }
}

// MARK: - Generate Form
private struct GenerateFormView: View {
    @ObservedObject var accountVM:  AccountViewModel
    @ObservedObject var qrVM:       QrViewModel
    @Binding var selectedAccount:   String
    @Binding var amountText:        String
    @Binding var note:              String
    @Binding var ttl:               Int
    let onDismiss: () -> Void

    // ── Derived helpers ───────────────────────────────────────────────────
    /// The account currently selected by the user (nil if none chosen yet)
    private var selectedAccountModel: AccountModel? {
        accountVM.accounts.first { $0.accountNumber == selectedAccount }
    }

    /// Parsed amount from the text field (nil when empty or zero)
    private var enteredAmount: Double? {
        guard let v = Double(amountText), v > 0 else { return nil }
        return v
    }

    /// True when the entered amount is greater than the selected account balance
    private var exceedsBalance: Bool {
        guard let amt = enteredAmount,
              let acc = selectedAccountModel else { return false }
        return amt > acc.balance
    }

    /// The generate button should be disabled when no account is selected OR
    /// the amount exceeds the account balance
    private var canGenerate: Bool {
        !selectedAccount.isEmpty && !exceedsBalance
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Nav bar ───────────────────────────────────────────────────
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Account selector
                    sectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            label("Deposit into")
                            if accountVM.isLoading {
                                SkeletonView().frame(height: 56).skeletonCorner(12)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(accountVM.accounts) { acc in
                                            AccountPill(
                                                acc: acc,
                                                selected: selectedAccount == acc.accountNumber
                                            ) { selectedAccount = acc.accountNumber }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Amount + Note side by side
                    sectionCard {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                label("Amount (optional)")
                                HStack {
                                    Text("$")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Color.titanSecondary)
                                    TextField("0.00", text: $amountText)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 17, design: .rounded))
                                        .foregroundStyle(exceedsBalance ? Color.titanOutflow : Color.titanDark)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.titanSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            exceedsBalance ? Color.titanOutflow : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )

                                // ── Balance warning ───────────────────────
                                if exceedsBalance, let acc = selectedAccountModel {
                                    HStack(spacing: 5) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 11))
                                        Text("Exceeds account balance (\(acc.balance, format: .currency(code: acc.currency)))")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(Color.titanOutflow)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                label("Note (optional)")
                                TextField("e.g. Lunch split", text: $note)
                                    .font(.system(size: 15))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.titanSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Expiry
                    sectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            label("Expires in")
                            HStack(spacing: 8) {
                                ForEach([5, 15, 30, 60], id: \.self) { mins in
                                    Button { ttl = mins } label: {
                                        Text("\(mins)m")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(ttl == mins ? .white : Color.titanPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(
                                                ttl == mins
                                                ? Color.titanPrimary
                                                : Color.titanPrimary.opacity(0.08)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let err = qrVM.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.titanOutflow)
                                .font(.caption)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color.titanOutflow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }

                    TitanPrimaryButton(
                        label: "Generate QR Code",
                        isLoading: qrVM.isLoading
                    ) {
                        Task {
                            let amt = Double(amountText) ?? 0
                            await qrVM.generateQr(
                                payeeAccountNumber: selectedAccount,
                                amount:     amt > 0 ? amt : nil,
                                note:       note.isEmpty ? nil : note,
                                ttlMinutes: ttl
                            )
                        }
                    }
                    .disabled(!canGenerate)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: exceedsBalance)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.titanDark)
                    .padding(10)
                    .background(Color.titanSurface)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Receive Money")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.titanDark)
            Spacer()
            // Balance spacer
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }
}

// MARK: - Active QR Display
private struct ActiveQrView: View {
    let qr:     QrPaymentResponse
    let b64:    String
    @ObservedObject var qrVM: QrViewModel
    @Binding var showCancelAlert: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Nav
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.titanDark)
                        .padding(10)
                        .background(Color.titanSurface)
                        .clipShape(Circle())
                }
                Spacer()
                Text("My QR Code")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.titanDark)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 20)

            Spacer()

            // ── Centered QR card ─────────────────────────────────────────
            VStack(spacing: 0) {

                // Top meta: account + note
                VStack(spacing: 4) {
                    Text("···· \(qr.payeeAccountNumber.suffix(4))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.titanSecondary)
                    if let n = qr.note, !n.isEmpty {
                        Text(n)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.titanSecondary)
                    }
                }
                .padding(.bottom, 16)

                // Amount
                if let amt = qr.amount, let cur = qr.currency {
                    Text(amt, format: .currency(code: cur))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.titanDark)
                        .padding(.bottom, 20)
                } else {
                    Text("Open Amount")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.titanSecondary)
                        .padding(.bottom, 20)
                }

                // QR image — always centered
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                        .frame(width: 256, height: 256)

                    if let img = qrVM.qrUIImage(from: b64) {
                        Image(uiImage: img)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 216, height: 216)
                    } else {
                        ProgressView()
                    }
                }

                // Expiry + status
                VStack(spacing: 8) {
                    if let exp = qr.expiresAt {
                        ExpiryCountdownView(expiresAt: exp)
                    }
                    statusPill(qr.status)
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // Cancel button
            if qr.status.uppercased() == "PENDING" {
                Button { showCancelAlert = true } label: {
                    Label("Cancel this QR", systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.titanOutflow)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }

    private func statusPill(_ status: String) -> some View {
        let (color, icon): (Color, String) = {
            switch status.uppercased() {
            case "SUCCESS":   return (.titanInflow,  "checkmark.circle.fill")
            case "EXPIRED":   return (.titanOutflow, "clock.badge.xmark.fill")
            case "CANCELLED": return (.titanOutflow, "xmark.circle.fill")
            default:          return (.titanPrimary, "clock.fill")
            }
        }()
        return Label(status.capitalized, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

// MARK: - Expiry Countdown
private struct ExpiryCountdownView: View {
    let expiresAt: Date
    @State private var remaining = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 11))
            Text(remaining)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(expiringSoon ? Color.titanOutflow : Color.titanSecondary)
        .onAppear { tick() }
        .onReceive(timer) { _ in tick() }
    }

    private var expiringSoon: Bool { expiresAt.timeIntervalSinceNow < 60 }

    private func tick() {
        let diff = expiresAt.timeIntervalSinceNow
        if diff <= 0 { remaining = "Expired" }
        else { remaining = String(format: "%d:%02d left", Int(diff) / 60, Int(diff) % 60) }
    }
}

// MARK: - Account Pill
private struct AccountPill: View {
    let acc:      AccountModel
    let selected: Bool
    let onTap:    () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(selected ? .white.opacity(0.3) : Color.titanPrimary.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(selected ? .white : Color.titanPrimary)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("···· \(acc.accountNumber.suffix(4))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(selected ? .white : Color.titanDark)
                    Text(acc.balance, format: .currency(code: acc.currency))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(selected ? .white.opacity(0.8) : Color.titanSecondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? Color.titanPrimary : Color.titanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? .clear : Color.titanPrimary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers
private func label(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10, weight: .bold))
        .tracking(1.2)
        .foregroundStyle(Color.titanSecondary)
}

private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.titanBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
}
