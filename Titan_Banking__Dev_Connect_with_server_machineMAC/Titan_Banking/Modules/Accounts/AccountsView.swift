import SwiftUI

struct AccountsView: View {
    @StateObject private var vm = AccountViewModel()
    @State private var showCreate = false
    @State private var showStatements = false
    @State private var selectedAccount: AccountModel?  // opens full AccountDetailView
    @State private var qrAccount: AccountModel?        // opens QR-only sheet

    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if vm.isLoading && vm.accounts.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonView().frame(height: 88).skeletonCorner(20).padding(.horizontal, 20)
                        }
                    } else if vm.accounts.isEmpty {
                        ContentUnavailableView("No Accounts", systemImage: "creditcard",
                            description: Text("Tap + to open your first account"))
                            .padding(.top, 60)
                    } else {
                        ForEach(vm.accounts) { account in
                            AccountCardView(
                                account: account,
                                onTap: {
                                    selectedAccount = account
                                },
                                onQrTap: {
                                    qrAccount = account
                                }
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showStatements = true
                } label: {
                    Image(systemName: "doc.text")
                }
                .disabled(vm.accounts.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
            }
        }
        .task { await vm.loadAccounts() }
        .refreshable { await vm.loadAccounts() }
        .sheet(isPresented: $showCreate) { CreateAccountSheet(vm: vm) }
        .sheet(isPresented: $showStatements) {
            StatementDownloadView(accounts: vm.accounts)
        }
        .sheet(item: $selectedAccount) { account in
            AccountDetailView(account: account, vm: vm)
        }
        // QR-only popup — just the QR image + Scan to Pay
        .sheet(item: $qrAccount) { account in
            AccountQrSheet(account: account)
        }
    }
}

// MARK: - Account QR Sheet  (QR icon shortcut — show QR + Scan to Pay only)

struct AccountQrSheet: View {
    let account: AccountModel
    @StateObject private var qrVM = QrViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showQrPay = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── QR image ──────────────────────────────────────────────
                    Group {
                        if qrVM.accountQrLoading {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .frame(width: 260, height: 260)
                                .overlay(ProgressView())
                        } else if let base64 = qrVM.accountQr?.qrImageBase64,
                                  let img = qrVM.qrUIImage(from: base64) {
                            Image(uiImage: img)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 240, height: 240)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                        } else if let err = qrVM.errorMessage {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .frame(width: 260, height: 260)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.title2).foregroundStyle(.red)
                                        Text(err).font(.caption).foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center).padding(.horizontal, 16)
                                    }
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .frame(width: 260, height: 260)
                                .overlay(ProgressView())
                        }
                    }

                    // ── Account number watermark ──────────────────────────────
                    VStack(spacing: 4) {
                        Text("Scan to receive payment")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(account.accountNumber)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Color.titanPrimary)
                    }

                    // ── Scan to Pay button ────────────────────────────────────
                    Button {
                        showQrPay = true
                    } label: {
                        Label("Scan to Pay", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .navigationTitle("Account QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await qrVM.refreshAccountQr(accountNumber: account.accountNumber) }
                    } label: {
                        if qrVM.accountQrLoading { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .task { await qrVM.loadAccountQr(accountNumber: account.accountNumber) }
            .fullScreenCover(isPresented: $showQrPay) { QrPayFlowView() }
        }
    }
}

// MARK: - Account Detail (GET /api/v1/accounts/{id})

struct AccountDetailView: View {
    let account: AccountModel
    @ObservedObject var vm: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var detail: AccountModel?
    @State private var isRefreshing = false

    private var shown: AccountModel { detail ?? account }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("ID", value: "\(shown.id)")
                    LabeledContent("Number", value: shown.accountNumber)
                    LabeledContent("Type", value: shown.accountType)
                    LabeledContent("Currency", value: shown.currency)
                    LabeledContent("Status", value: shown.status)
                }
                Section("Balance") {
                    Text(shown.balance, format: .currency(code: shown.currency))
                        .font(.title2.bold())
                        .foregroundStyle(Color.titanPrimary)
                }
                if let err = vm.errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Account Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let fresh = await vm.fetchAccount(id: account.id) {
            detail = fresh
        }
    }
}

// MARK: - Account Card

struct AccountCardView: View {
    let account: AccountModel
    var onTap: (() -> Void)? = nil
    var onQrTap: (() -> Void)? = nil
    @State private var copied = false

    var body: some View {
        Button(action: { onTap?() }) {
            TitanCard {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(account.accountType.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.titanSecondary)

                        // Account number + copy + QR shortcut (strict 1-line layout)
                        HStack(spacing: 6) {
                            Text(account.accountNumber)
                                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.titanPrimary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            // Copy button
                            Button {
                                UIPasteboard.general.string = account.accountNumber
                                Haptics.success()
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                            } label: {
                                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundStyle(copied ? Color.titanInflow : Color.titanSecondary)
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)

                            // QR shortcut — taps directly into QR tab
                            Button {
                                onQrTap?()
                            } label: {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.titanPrimary.opacity(0.75))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(account.balance, format: .currency(code: account.currency))
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.titanPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(account.status == "ACTIVE" ? Color.titanInflow : Color.titanOutflow)
                                .frame(width: 7, height: 7)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.titanSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Account Sheet

struct CreateAccountSheet: View {
    @ObservedObject var vm: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var accountType = "SAVINGS"
    @State private var currency = "USD"

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Type") {
                    Picker("Type", selection: $accountType) {
                        Text("Savings").tag("SAVINGS")
                        Text("Checking").tag("CHECKING")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Currency") {
                    Picker("Currency", selection: $currency) {
                        Text("USD").tag("USD")
                        Text("KHR").tag("KHR")
                    }
                    .pickerStyle(.segmented)
                }
                if let msg = vm.successMessage {
                    Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if let err = vm.errorMessage {
                    Label(err, systemImage: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .navigationTitle("New Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await vm.createAccount(type: accountType, currency: currency)
                            if vm.successMessage != nil { dismiss() }
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
    }
}
