import SwiftUI
import PhotosUI

// MARK: - QR Pay Flow
struct QrPayFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var qrVM      = QrViewModel()
    @StateObject private var accountVM = AccountViewModel()

    @State private var selectedTab: QrTab = .scan
    @State private var step: QrPayStep    = .scan
    @State private var scannedCode: String = ""
    @State private var isTorchOn: Bool     = false

    private enum QrTab: String, CaseIterable {
        case scan = "Scan QR"
        case myQr = "My QR Code"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.titanBackground.ignoresSafeArea()

            switch step {
            case .scan:
                ZStack(alignment: .top) {
                    if selectedTab == .scan {
                        #if targetEnvironment(simulator)
                        SimulatorQrEntryView(
                            onScan: { code in
                                scannedCode = code
                                step = .confirm
                            },
                            onCancel: { dismiss() }
                        )
                        #else
                        QrScannerView(
                            onScan: { code in
                                scannedCode = code
                                step = .confirm
                            },
                            onCancel: { dismiss() },
                            isTorchOn: $isTorchOn
                        )
                        #endif
                    } else {
                        MyQrReceiveView(
                            accountVM: accountVM,
                            qrVM: qrVM,
                            onClose: { dismiss() }
                        )
                    }

                    // Unified Top Navigation Bar
                    topFloatingBar
                }

            case .confirm:
                QrConfirmView(
                    qrCode: scannedCode,
                    qrVM: qrVM,
                    accountVM: accountVM,
                    onSuccess: { step = .success },
                    onRescan: { step = .scan },
                    onCancel: { dismiss() }
                )

            case .success:
                QrSuccessView(
                    qr: qrVM.activeQr,
                    onDone: { dismiss() }
                )
            }
        }
        .task {
            await accountVM.loadAccounts()
        }
    }

    // MARK: - Top Floating Bar (Always Reliable Back & Mode Switch)
    private var topFloatingBar: some View {
        HStack {
            FloatingBackButton(icon: "xmark") {
                dismiss()
            }

            Spacer()

            tabPicker

            Spacer()

            if selectedTab == .scan {
                Button {
                    Haptics.tap()
                    isTorchOn.toggle()
                } label: {
                    Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isTorchOn ? .yellow : .white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                }
                .bouncyButton(scale: 0.90)
            } else {
                Spacer().frame(width: 38)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
    }

    // MARK: - Tab Picker Header
    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(QrTab.allCases, id: \.self) { tab in
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selectedTab == tab ? (selectedTab == .scan ? .white : Color.titanPrimary) : .white.opacity(0.70))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            selectedTab == tab
                            ? (selectedTab == .scan ? Color.white.opacity(0.25) : Color.white)
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .bouncyButton(scale: 0.95)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}

private enum QrPayStep: Equatable { case scan, confirm, success }

// MARK: - My QR Receive View
private struct MyQrReceiveView: View {
    @ObservedObject var accountVM: AccountViewModel
    @ObservedObject var qrVM: QrViewModel
    let onClose: () -> Void

    @State private var selectedAccount: String = ""
    @State private var customAmount: String = ""
    @State private var customNote: String = ""
    @State private var isCustomQr = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.18, blue: 0.58),
                        Color(red: 0.08, green: 0.32, blue: 0.78),
                        Color.titanBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 110)

                        // ── QR Card ───────────────────────────────────────
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color.titanPrimary)
                                Text("TITAN KHQR")
                                    .font(.system(size: 16, weight: .black))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.titanPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)

                            Divider().padding(.horizontal, 16)

                            // QR Image display
                            Group {
                                if qrVM.accountQrLoading || qrVM.isLoading {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 220, height: 220)
                                        .overlay(ProgressView().scaleEffect(1.2))
                                } else if let qr = qrVM.activeQr ?? qrVM.accountQr,
                                          let b64 = qr.qrImageBase64,
                                          let img = qrVM.qrUIImage(from: b64) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 220, height: 220)
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                                } else {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 220, height: 220)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "qrcode")
                                                    .font(.system(size: 40))
                                                    .foregroundStyle(Color.secondary)
                                                Text("Loading QR...")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondary)
                                            }
                                        )
                                }
                            }

                            // Account and Info
                            VStack(spacing: 4) {
                                Text("Account Number")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                                Text(selectedAccount.isEmpty ? "···" : selectedAccount)
                                    .font(.system(.headline, design: .monospaced).weight(.bold))
                                    .foregroundStyle(Color.titanDark)

                                if let amt = Double(customAmount), amt > 0 {
                                    Text(amt, format: .currency(code: "USD"))
                                        .font(.system(size: 20, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.titanPrimary)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
                        .padding(.horizontal, 28)

                        // ── Account Selector ──────────────────────────────
                        if accountVM.accounts.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("RECEIVING ACCOUNT")
                                    .font(.caption2.bold())
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 28)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(accountVM.accounts) { acc in
                                            Button {
                                                Haptics.selection()
                                                selectedAccount = acc.accountNumber
                                                Task {
                                                    await qrVM.loadAccountQr(accountNumber: acc.accountNumber)
                                                }
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(acc.accountType)
                                                        .font(.system(size: 11, weight: .semibold))
                                                    Text("···· \(acc.accountNumber.suffix(4))")
                                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(selectedAccount == acc.accountNumber ? Color.white : Color.white.opacity(0.15))
                                                .foregroundStyle(selectedAccount == acc.accountNumber ? Color.titanPrimary : Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                            .bouncyButton(scale: 0.94)
                                        }
                                    }
                                    .padding(.horizontal, 28)
                                }
                            }
                        }

                        // ── Custom Amount Action ──────────────────────────
                        VStack(spacing: 14) {
                            if isCustomQr {
                                VStack(spacing: 12) {
                                    TextField("Enter Amount ($)", text: $customAmount)
                                        .keyboardType(.decimalPad)
                                        .padding(14)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .foregroundStyle(Color.black)

                                    // Quick amount chips
                                    HStack(spacing: 8) {
                                        ForEach([5, 10, 25, 50, 100], id: \.self) { preset in
                                            Button {
                                                Haptics.selection()
                                                let curr = Double(customAmount) ?? 0
                                                customAmount = String(format: "%.0f", curr + Double(preset))
                                            } label: {
                                                Text("+\(preset)$")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 10)
                                                    .background(Color.white.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                            .bouncyButton(scale: 0.92)
                                        }
                                    }

                                    TextField("Note (optional)", text: $customNote)
                                        .padding(14)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .foregroundStyle(Color.black)

                                    HStack(spacing: 10) {
                                        Button {
                                            Haptics.tap()
                                            Task {
                                                guard let amt = Double(customAmount), amt > 0 else { return }
                                                await qrVM.generateQr(
                                                    payeeAccountNumber: selectedAccount,
                                                    amount: amt,
                                                    note: customNote.isEmpty ? nil : customNote
                                                )
                                            }
                                        } label: {
                                            Text("Generate QR")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 14)
                                                .background(Color.titanPrimary)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .bouncyButton(scale: 0.95)

                                        Button {
                                            Haptics.tap()
                                            withAnimation {
                                                isCustomQr = false
                                                customAmount = ""
                                                customNote = ""
                                                qrVM.activeQr = nil
                                            }
                                        } label: {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(14)
                                                .background(Color.white.opacity(0.20))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .bouncyButton(scale: 0.92)
                                    }
                                }
                                .padding(.horizontal, 28)
                            } else {
                                HStack(spacing: 12) {
                                    Button {
                                        Haptics.tap()
                                        withAnimation { isCustomQr = true }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "dollarsign.circle.fill")
                                            Text("Set Amount")
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 18)
                                        .background(Color.white.opacity(0.18))
                                        .clipShape(Capsule())
                                    }
                                    .bouncyButton(scale: 0.94)

                                    if let qr = qrVM.activeQr ?? qrVM.accountQr,
                                       let b64 = qr.qrImageBase64,
                                       let img = qrVM.qrUIImage(from: b64) {
                                        ShareLink(
                                            item: Image(uiImage: img),
                                            preview: SharePreview("Titan KHQR - \(selectedAccount)", image: Image(uiImage: img))
                                        ) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "square.and.arrow.up.fill")
                                                Text("Share")
                                            }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.titanPrimary)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 18)
                                            .background(Color.white)
                                            .clipShape(Capsule())
                                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                                        }
                                        .bouncyButton(scale: 0.94)
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                if selectedAccount.isEmpty, let first = accountVM.accounts.first {
                    selectedAccount = first.accountNumber
                    await qrVM.loadAccountQr(accountNumber: first.accountNumber)
                }
            }
        }
    }
}

// MARK: - Simulator QR Entry
/// On simulator (no camera), show a text field to paste the QR token manually.
private struct SimulatorQrEntryView: View {
    let onScan:   (String) -> Void
    let onCancel: () -> Void

    @State private var code = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "camera.slash.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))

                    Text("Simulator — no camera available")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("Paste a QR token to test payment flow")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 32)

                VStack(spacing: 12) {
                    TextField("QR token", text: $code)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(14)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onScan(code.trimmingCharacters(in: .whitespaces))
                    } label: {
                        Text("Continue →")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(code.isEmpty ? Color.gray.opacity(0.3) : Color.titanPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}

// MARK: - Confirm Step
private struct QrConfirmView: View {
    let qrCode: String
    @ObservedObject var qrVM:     QrViewModel
    @ObservedObject var accountVM: AccountViewModel

    let onSuccess: () -> Void
    let onRescan:  () -> Void
    let onCancel:  () -> Void

    @State private var selectedAccount = ""
    @State private var pin             = ""
    @State private var manualAmount:  String = ""
    @State private var dragOffset:    CGFloat = 0
    @State private var confirmed      = false

    private let trackWidth: CGFloat = 300
    private let thumbSize:  CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Navigation Bar (Back & Cancel) ─────────────────────────
            HStack {
                FloatingBackButton(icon: "chevron.left") {
                    onRescan()
                }

                Spacer()

                Text("Confirm Payment")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.titanDark)

                Spacer()

                Button {
                    Haptics.tap()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.titanOutflow)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .background(Color.titanOutflow.opacity(0.12))
                        .clipShape(Capsule())
                }
                .bouncyButton(scale: 0.92)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    // ── Scanned code preview ───────────────────────────────────
                    TitanCard {
                        HStack(spacing: 14) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.titanPrimary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("QR Token")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.titanSecondary)
                                Text(String(qrCode.prefix(20)) + (qrCode.count > 20 ? "…" : ""))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Color.titanDark)
                            }
                            Spacer()
                            Button(action: onRescan) {
                                Text("Re-scan")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.titanPrimary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.titanPrimary.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .bouncyButton(scale: 0.92)
                        }
                        .padding(16)
                    }

                    // ── From Account picker ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PAY FROM")
                            .font(.system(.caption2, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.titanSecondary)

                        if accountVM.isLoading {
                            SkeletonView().frame(height: 64).skeletonCorner(14)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(accountVM.accounts) { acc in
                                        QrAccountChip(
                                            account: acc,
                                            isSelected: selectedAccount == acc.accountNumber
                                        ) {
                                            Haptics.selection()
                                            selectedAccount = acc.accountNumber
                                        }
                                    }
                                }
                            }
                            if accountVM.accounts.isEmpty {
                                Text("No accounts found.")
                                    .font(.caption)
                                    .foregroundStyle(Color.titanSecondary)
                            }
                        }
                    }

                    // ── Optional amount (for open-amount QR) ──────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT (optional — leave blank if QR is fixed)")
                            .font(.system(.caption2, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.titanSecondary)

                        TextField("0.00", text: $manualAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .rounded))
                            .padding()
                            .background(Color.titanSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // ── PIN ────────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENTER PIN")
                            .font(.system(.caption2, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.titanSecondary)

                        SecureField("PIN (4–6 digits)", text: $pin)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.titanSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // ── Error ──────────────────────────────────────────────────
                    if let err = qrVM.errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.titanOutflow)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if qrVM.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(Color.titanPrimary)
                            Text("Processing payment…")
                                .font(.caption)
                                .foregroundStyle(Color.titanSecondary)
                        }
                    }

                    // ── Swipe to Confirm ───────────────────────────────────────
                    VStack(spacing: 10) {
                        swipeTrack
                        Text(pin.count >= 4 && !selectedAccount.isEmpty
                             ? "Slide to pay"
                             : "Select account and enter PIN first")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(Color.titanSecondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
        .onAppear {
            if selectedAccount.isEmpty, let first = accountVM.accounts.first {
                selectedAccount = first.accountNumber
            }
        }
    }

    private var canSwipe: Bool { pin.count >= 4 && !selectedAccount.isEmpty }

    private var swipeTrack: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: thumbSize / 2)
                .fill(Color.titanSurface)
                .frame(width: trackWidth, height: thumbSize)

            RoundedRectangle(cornerRadius: thumbSize / 2)
                .fill(confirmed ? Color.titanInflow : Color.titanAccent.opacity(0.2))
                .frame(width: max(thumbSize, dragOffset + thumbSize), height: thumbSize)
                .animation(.spring(response: 0.3), value: confirmed)

            Circle()
                .fill(canSwipe ? (confirmed ? Color.titanInflow : Color.titanAccent) : Color.gray.opacity(0.4))
                .frame(width: thumbSize, height: thumbSize)
                .overlay {
                    Image(systemName: confirmed ? "checkmark" : "chevron.right.2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            guard canSwipe else { return }
                            dragOffset = min(max(0, v.translation.width), trackWidth - thumbSize)
                            if dragOffset > 0 { qrVM.errorMessage = nil }
                        }
                        .onEnded { _ in
                            guard canSwipe else {
                                withAnimation(.spring()) { dragOffset = 0 }
                                qrVM.errorMessage = "Please select an account and enter your PIN."
                                return
                            }
                            if dragOffset > (trackWidth - thumbSize) * 0.8 {
                                dragOffset = trackWidth - thumbSize
                                confirmed = true
                                submit()
                            } else {
                                withAnimation(.spring()) { dragOffset = 0 }
                            }
                        }
                )
                .animation(.interactiveSpring(), value: dragOffset)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(confirmed || qrVM.isLoading)
    }

    private func submit() {
        let amount = Double(manualAmount.isEmpty ? "0" : manualAmount)
        Task {
            let ok = await qrVM.payByQr(
                qrCode:             qrCode,
                payerAccountNumber: selectedAccount,
                amount:             (amount ?? 0) > 0 ? amount : nil,
                pin:                pin
            )
            if ok {
                Haptics.success()
                try? await Task.sleep(for: .seconds(0.6))
                onSuccess()
            } else {
                Haptics.error()
                withAnimation(.spring()) { dragOffset = 0; confirmed = false }
            }
        }
    }
}

// MARK: - Account Chip
private struct QrAccountChip: View {
    let account:    AccountModel
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.accountType)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.titanSecondary)
                Text("···· \(account.accountNumber.suffix(4))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : Color.titanDark)
                Text(account.balance, format: .currency(code: account.currency))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.titanSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.titanPrimary : Color.titanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? .clear : Color.titanPrimary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.titanPrimary.opacity(0.3) : .clear, radius: 6, y: 3)
        }
        .bouncyButton(scale: 0.94)
    }
}

// MARK: - Success Step
private struct QrSuccessView: View {
    let qr:     QrPaymentResponse?
    let onDone: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.titanInflow.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .scaleEffect(appear ? 1 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 66))
                    .foregroundStyle(Color.titanInflow)
                    .scaleEffect(appear ? 1 : 0.2)
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.65), value: appear)

            VStack(spacing: 8) {
                Text("Payment Sent!")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(Color.titanDark)

                if let amt = qr?.amount, let cur = qr?.currency {
                    Text(amt, format: .currency(code: cur))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.titanPrimary)
                }

                if let payee = qr?.payeeAccountNumber {
                    Text("To ···· \(payee.suffix(4))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.titanSecondary)
                }

                if let txId = qr?.transactionId {
                    Text("Ref: TX-\(txId)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.titanSecondary)
                }
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.2), value: appear)

            Spacer()

            TitanPrimaryButton(label: "Done", isLoading: false, action: onDone)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(appear ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.35), value: appear)
        }
        .onAppear {
            Haptics.success()
            appear = true
        }
    }
}
