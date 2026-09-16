import Foundation
import Combine

// MARK: - LoanViewModel

@MainActor
final class LoanViewModel: ObservableObject {

    // ── Published state ───────────────────────────────────────────────────────
    @Published var loans: [LoanModel] = []
    @Published var repayments: [LoanRepaymentModel] = []
    @Published var selectedLoanId: Int? = nil

    @Published var isLoading = false
    @Published var isLoadingRepayments = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// Live eligibility info shown while user types amount
    @Published var eligibilityInfo: EligibilityInfo? = nil

    // ── Account selector (populated from AccountsView) ────────────────────────
    @Published var selectedAccount: AccountModel? = nil

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Eligibility Rules (mirrors server-side LoanEligibilityService)
    // ─────────────────────────────────────────────────────────────────────────

    struct EligibilityInfo {
        let balance: Double
        let maxLoanAmount: Double        // 10% of balance
        let requestedAmount: Double
        let processingFee: Double        // 4% of requested
        let monthlyPayment: Double       // 5%/month amortization
        let totalRepayment: Double
        let isEligible: Bool
        let termMonths: Int

        var errorMessage: String? {
            guard !isEligible else { return nil }
            return String(format:
                "Amount $%.2f exceeds limit of $%.2f (max 10%% of your balance $%.2f)",
                requestedAmount, maxLoanAmount, balance)
        }
    }

    /// Called whenever amount or term changes in the apply sheet.
    func updateEligibility(amount: Double, termMonths: Int) {
        guard let balance = selectedAccount.map({ $0.balance }), balance > 0 else {
            eligibilityInfo = nil
            return
        }
        let maxLoan      = (balance * 0.10 * 100).rounded(.down) / 100  // floor to 2dp
        let fee          = (amount * 0.04 * 100).rounded() / 100
        let monthly      = monthlyPayment(principal: amount, months: termMonths)
        let isEligible   = amount <= maxLoan && amount > 0

        eligibilityInfo = EligibilityInfo(
            balance: balance,
            maxLoanAmount: maxLoan,
            requestedAmount: amount,
            processingFee: fee,
            monthlyPayment: monthly,
            totalRepayment: monthly * Double(termMonths),
            isEligible: isEligible,
            termMonths: termMonths
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Apply for a Loan
    // ─────────────────────────────────────────────────────────────────────────

    func applyLoan(amount: Double, termMonths: Int, note: String) async {
        guard let account = selectedAccount else {
            errorMessage = "Please select an account first."
            return
        }
        guard let info = eligibilityInfo, info.isEligible else {
            errorMessage = eligibilityInfo?.errorMessage ?? "Amount not eligible."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let request = LoanRequest(
                accountId: account.id,
                accountNumber: account.accountNumber,
                amount: amount,
                termMonths: termMonths,
                note: note.isEmpty ? nil : note
            )
            let loan = try await APIClient.shared.loanRequest(
                .applyLoan(request),
                responseType: LoanModel.self
            )
            loans.insert(loan, at: 0)
            successMessage = "Loan #\(loan.id) submitted — status: \(loan.status)"
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Approve a Loan
    // ─────────────────────────────────────────────────────────────────────────

    func approveLoan(id: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.loanRequest(
                .approveLoan(id),
                responseType: LoanApprovalResponse.self
            )
            successMessage = String(format:
                "Loan #%d approved! Monthly: $%.2f, Fee: $%.2f",
                result.loanId, result.monthlyPayment, result.processingFee)

            // Update in local list
            if let idx = loans.firstIndex(where: { $0.id == id }) {
                let old = loans[idx]
                loans[idx] = LoanModel(
                    id: old.id,
                    accountId: old.accountId,
                    accountNumber: old.accountNumber,
                    username: old.username,
                    amount: old.amount,
                    interestRate: old.interestRate,
                    termMonths: old.termMonths,
                    monthlyPayment: result.monthlyPayment,
                    processingFee: result.processingFee,
                    status: "APPROVED",
                    note: old.note,
                    appliedAt: old.appliedAt,
                    approvedAt: nil,
                    rejectedAt: nil
                )
            }
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Reject a Loan
    // ─────────────────────────────────────────────────────────────────────────

    func rejectLoan(id: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loan = try await APIClient.shared.loanRequest(
                .rejectLoan(id),
                responseType: LoanModel.self
            )
            if let idx = loans.firstIndex(where: { $0.id == id }) {
                loans[idx] = loan
            }
            successMessage = "Loan #\(loan.id) rejected."
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Fetch My Loans
    // ─────────────────────────────────────────────────────────────────────────

    func fetchMyLoans() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            loans = try await APIClient.shared.loanRequest(
                .getMyLoans,
                responseType: [LoanModel].self
            )
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    /// GET /api/v1/loans/{id}
    func fetchLoanById(_ id: Int) async -> LoanModel? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loan = try await APIClient.shared.loanRequest(
                .getLoanById(id),
                responseType: LoanModel.self
            )
            if let idx = loans.firstIndex(where: { $0.id == id }) {
                loans[idx] = loan
            } else {
                loans.insert(loan, at: 0)
            }
            return loan
        } catch {
            errorMessage = errorMessage(from: error)
            return nil
        }
    }

    /// GET /api/v1/loans/account/{accountId}
    func fetchLoansByAccount(_ accountId: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            loans = try await APIClient.shared.loanRequest(
                .getByAccount(accountId),
                responseType: [LoanModel].self
            )
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Fetch Repayment Schedule
    // ─────────────────────────────────────────────────────────────────────────

    func fetchRepayments(for loanId: Int) async {
        isLoadingRepayments = true
        selectedLoanId = loanId
        defer { isLoadingRepayments = false }
        do {
            repayments = try await APIClient.shared.loanRequest(
                .getRepaymentSchedule(loanId),
                responseType: [LoanRepaymentModel].self
            )
        } catch {
            errorMessage = errorMessage(from: error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Amortization (client-side, mirrors server logic)
    //         Monthly rate = 5% per month (fixed)
    // ─────────────────────────────────────────────────────────────────────────

    /// Use server-provided monthlyPayment when available, compute locally as fallback.
    func monthlyPayment(for loan: LoanModel) -> Double {
        if let mp = loan.monthlyPayment, mp > 0 { return mp }
        return monthlyPayment(principal: loan.amount, months: loan.termMonths)
    }

    func processingFee(for loan: LoanModel) -> Double {
        if let fee = loan.processingFee, fee > 0 { return fee }
        return (loan.amount * 0.04 * 100).rounded() / 100
    }

    /// Standard amortization: M = P × [r(1+r)^n] / [(1+r)^n − 1]
    /// r = 0.05 (5% per month, fixed)
    private func monthlyPayment(principal: Double, months: Int) -> Double {
        let r = 0.05
        let n = Double(months)
        guard months > 0, principal > 0 else { return 0 }
        if r == 0 { return principal / n }
        let factor = pow(1 + r, n)
        return (principal * r * factor / (factor - 1) * 100).rounded() / 100
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────────────────

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func errorMessage(from error: Error) -> String {
        if let apiErr = error as? APIError {
            return apiErr.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
}
