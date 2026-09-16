import SwiftUI

struct LoansView: View {
    @StateObject private var vm = LoanViewModel()
    @State private var showApply = false
    @State private var selectedLoan: LoanModel? = nil
    @State private var showFilterByAccount = false
    @State private var filterAccountId = ""
    @State private var lookupLoanId = ""
    @State private var showLookup = false

    /// When true the view was pushed as fullScreenCover (from Dashboard quick action).
    /// A Close button is shown so the user can dismiss it.
    /// When false it is a tab-bar root — no dismiss button needed.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    var body: some View {
        ZStack {
            if vm.isLoading && vm.loans.isEmpty {
                ProgressView("Loading loans...")
            } else if vm.loans.isEmpty {
                ContentUnavailableView(
                    "No Loans",
                    systemImage: "doc.text.fill",
                    description: Text("Apply for your first loan to get started")
                )
            } else {
                List {
                    ForEach(vm.loans) { loan in
                        LoanCardView(loan: loan, vm: vm) {
                            selectedLoan = loan
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Loans")
        .toolbar {
            // ── Close button (only when presented modally from Dashboard) ────
            if isPresented {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        vm.clearMessages()
                        showApply = true
                    } label: {
                        Label("Apply for loan", systemImage: "plus.circle")
                    }
                    Button {
                        showFilterByAccount = true
                    } label: {
                        Label("Filter by account ID", systemImage: "building.columns")
                    }
                    Button {
                        showLookup = true
                    } label: {
                        Label("Lookup loan by ID", systemImage: "magnifyingglass")
                    }
                    Button {
                        Task { await vm.fetchMyLoans() }
                    } label: {
                        Label("My loans", systemImage: "person.crop.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showApply) {
            LoanApplicationSheet(vm: vm)
        }
        .sheet(item: $selectedLoan) { loan in
            LoanDetailView(loan: loan, vm: vm)
        }
        .alert("Loans by account", isPresented: $showFilterByAccount) {
            TextField("Account ID", text: $filterAccountId)
                .keyboardType(.numberPad)
            Button("Load") {
                if let id = Int(filterAccountId.trimmingCharacters(in: .whitespaces)) {
                    Task { await vm.fetchLoansByAccount(id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("GET /api/v1/loans/account/{accountId}")
        }
        .alert("Lookup loan", isPresented: $showLookup) {
            TextField("Loan ID", text: $lookupLoanId)
                .keyboardType(.numberPad)
            Button("Fetch") {
                if let id = Int(lookupLoanId.trimmingCharacters(in: .whitespaces)) {
                    Task {
                        if let loan = await vm.fetchLoanById(id) {
                            selectedLoan = loan
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("GET /api/v1/loans/{id}")
        }
        .task {
            await vm.fetchMyLoans()
        }
        .refreshable {
            await vm.fetchMyLoans()
        }
        .alert("Success", isPresented: .constant(vm.successMessage != nil), actions: {
            Button("OK") { vm.clearMessages() }
        }, message: {
            Text(vm.successMessage ?? "")
        })
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), actions: {
            Button("OK") { vm.clearMessages() }
        }, message: {
            Text(vm.errorMessage ?? "")
        })
    }
}

// MARK: - Loan Card

struct LoanCardView: View {
    let loan: LoanModel
    @ObservedObject var vm: LoanViewModel
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loan #\(loan.id)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(loan.amount, format: .currency(code: "USD"))
                        .font(.title2.bold())
                }
                Spacer()
                statusBadge
            }

            Divider()

            // Stats row
            HStack(spacing: 16) {
                LoanStat(label: "Term", value: "\(loan.termMonths) mo")
                LoanStat(label: "Monthly", value: vm.monthlyPayment(for: loan).formatted(.currency(code: "USD")))
                if loan.processingFee != nil {
                    LoanStat(label: "Fee", value: vm.processingFee(for: loan).formatted(.currency(code: "USD")))
                }
            }

            // Account info
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Account \(loan.accountNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Action buttons
            if loan.status == "PENDING" {
                HStack(spacing: 10) {
                    Button {
                        Task { await vm.approveLoan(id: loan.id) }
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.isLoading)

                    Button {
                        Task { await vm.rejectLoan(id: loan.id) }
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.isLoading)
                }

                Button {
                    onTap()
                } label: {
                    Label("View details", systemImage: "doc.text.magnifyingglass")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.blue)
                }
            } else if loan.status == "APPROVED" {
                Button {
                    onTap()
                } label: {
                    Label("View Repayment Schedule", systemImage: "calendar")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Note
            if let note = loan.note, !note.isEmpty {
                Text("Note: \(note)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private var statusBadge: some View {
        let (color, icon): (Color, String) = {
            switch loan.status {
            case "APPROVED": return (.green, "checkmark.circle.fill")
            case "PENDING":  return (.orange, "clock.fill")
            case "REJECTED": return (.red, "xmark.circle.fill")
            default:         return (.gray, "questionmark.circle.fill")
            }
        }()

        return HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(loan.status)
                .font(.caption.bold())
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

struct LoanStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loan Application Sheet

struct LoanApplicationSheet: View {
    @ObservedObject var vm: LoanViewModel
    @Environment(\.dismiss) private var dismiss

    // ── Fetch user's accounts ─────────────────────────────────────────────────
    @StateObject private var accountsVM = AccountViewModel()

    @State private var selectedAccountIndex: Int = 0
    @State private var amount = ""
    @State private var termMonths = 12
    @State private var note = ""

    private let terms = [6, 12, 24, 36, 60]

    var body: some View {
        NavigationStack {
            Form {
                // Account selector
                Section {
                    if accountsVM.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading accounts...")
                                .foregroundStyle(.secondary)
                        }
                    } else if accountsVM.accounts.isEmpty {
                        Text("No accounts found. Create an account first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: $selectedAccountIndex) {
                            ForEach(Array(accountsVM.accounts.enumerated()), id: \.offset) { idx, acc in
                                Text("\(acc.accountNumber) – \(acc.balance.formatted(.currency(code: "USD")))")
                                    .tag(idx)
                            }
                        }
                        .onChange(of: selectedAccountIndex) { _ in
                            updateSelection()
                            recalculateEligibility()
                        }
                    }
                } header: {
                    Text("Select Account")
                } footer: {
                    if let acc = selectedAccount {
                        Text("Available balance: \(acc.balance.formatted(.currency(code: "USD")))")
                    }
                }

                // Loan details
                Section("Loan Details") {
                    TextField("Amount (USD)", text: $amount)
                        .keyboardType(.decimalPad)
                        .onChange(of: amount) { _ in recalculateEligibility() }

                    Picker("Term", selection: $termMonths) {
                        ForEach(terms, id: \.self) { t in
                            Text("\(t) months").tag(t)
                        }
                    }
                    .onChange(of: termMonths) { _ in recalculateEligibility() }

                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Eligibility check
                if let info = vm.eligibilityInfo {
                    Section("Eligibility & Fees") {
                        if info.isEligible {
                            Label("Eligible", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label(info.errorMessage ?? "Not eligible", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        HStack {
                            Text("Max loan (10% of balance)")
                            Spacer()
                            Text(info.maxLoanAmount, format: .currency(code: "USD"))
                                .bold()
                        }

                        HStack {
                            Text("Processing fee (4%)")
                            Spacer()
                            Text(info.processingFee, format: .currency(code: "USD"))
                                .bold()
                        }

                        HStack {
                            Text("Monthly payment (5%/mo)")
                            Spacer()
                            Text(info.monthlyPayment, format: .currency(code: "USD"))
                                .bold()
                        }

                        HStack {
                            Text("Total repayment")
                            Spacer()
                            Text(info.totalRepayment, format: .currency(code: "USD"))
                                .bold()
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Messages
                if let err = vm.errorMessage {
                    Section {
                        Label(err, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Apply for Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isLoading ? "Submitting..." : "Apply") {
                        Task {
                            await submitLoan()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .task {
                await accountsVM.loadAccounts()
                updateSelection()
            }
        }
    }

    private var selectedAccount: AccountModel? {
        guard !accountsVM.accounts.isEmpty,
              selectedAccountIndex < accountsVM.accounts.count else { return nil }
        return accountsVM.accounts[selectedAccountIndex]
    }

    private var canSubmit: Bool {
        guard !vm.isLoading,
              let info = vm.eligibilityInfo,
              info.isEligible,
              selectedAccount != nil else { return false }
        return true
    }

    private func updateSelection() {
        vm.selectedAccount = selectedAccount
    }

    private func recalculateEligibility() {
        guard let amt = Double(amount), amt > 0 else {
            vm.eligibilityInfo = nil
            return
        }
        vm.updateEligibility(amount: amt, termMonths: termMonths)
    }

    private func submitLoan() async {
        guard let amt = Double(amount) else { return }
        await vm.applyLoan(amount: amt, termMonths: termMonths, note: note)
        if vm.successMessage != nil {
            dismiss()
        }
    }
}

// MARK: - Loan Detail View (Repayment Schedule)

struct LoanDetailView: View {
    let loan: LoanModel
    @ObservedObject var vm: LoanViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    HStack {
                        Text("Loan Amount")
                        Spacer()
                        Text(loan.amount, format: .currency(code: "USD"))
                            .bold()
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(loan.status)
                            .bold()
                            .foregroundStyle(statusColor(loan.status))
                    }
                    if let monthly = loan.monthlyPayment {
                        HStack {
                            Text("Monthly Payment")
                            Spacer()
                            Text(monthly, format: .currency(code: "USD"))
                                .bold()
                        }
                    }
                    if let fee = loan.processingFee {
                        HStack {
                            Text("Processing Fee")
                            Spacer()
                            Text(fee, format: .currency(code: "USD"))
                                .bold()
                        }
                    }
                    HStack {
                        Text("Term")
                        Spacer()
                        Text("\(loan.termMonths) months")
                    }
                    if let note = loan.note {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Note").font(.caption).foregroundStyle(.secondary)
                            Text(note).font(.subheadline)
                        }
                    }
                } header: {
                    Text("Loan Summary")
                }

                // Repayment schedule
                if loan.status == "APPROVED" {
                    Section {
                        if vm.isLoadingRepayments {
                            HStack {
                                ProgressView()
                                Text("Loading schedule...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if vm.repayments.isEmpty {
                            Text("No repayment schedule available.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.repayments) { repayment in
                                RepaymentRow(repayment: repayment)
                            }
                        }
                    } header: {
                        Text("Repayment Schedule")
                    }
                }
            }
            .navigationTitle("Loan #\(loan.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.bold())
                            Text("Back")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Refresh from GET /api/v1/loans/{id}, then load schedule if approved
                if let fresh = await vm.fetchLoanById(loan.id), fresh.status == "APPROVED" {
                    await vm.fetchRepayments(for: fresh.id)
                } else if loan.status == "APPROVED" {
                    await vm.fetchRepayments(for: loan.id)
                }
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "APPROVED": return .green
        case "PENDING": return .orange
        case "REJECTED": return .red
        default: return .gray
        }
    }
}

struct RepaymentRow: View {
    let repayment: LoanRepaymentModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Installment #\(repayment.installmentNumber)")
                    .font(.subheadline.bold())
                if let due = repayment.dueDate {
                    Text(due)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(repayment.amount, format: .currency(code: "USD"))
                    .font(.subheadline.bold())
                Text(repayment.status)
                    .font(.caption2.bold())
                    .foregroundStyle(repayment.status == "PAID" ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}
