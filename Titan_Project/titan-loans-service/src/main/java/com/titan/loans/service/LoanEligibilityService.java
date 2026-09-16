package com.titan.loans.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Encapsulates all loan eligibility and fee rules.
 *
 * ── Rules ────────────────────────────────────────────────────────────────────
 *
 * 1. Max loan amount = 10% of account balance
 *      balance  $1,000  → max loan    $100
 *      balance $10,000  → max loan  $1,000
 *      balance $50,000  → max loan  $5,000
 *
 * 2. Processing fee = 4% of loan amount  (charged upfront to the account)
 *
 * 3. Monthly interest rate = 5% per month (used in amortization formula)
 *    i.e. interestRate stored as 0.6000 (60% annual) but we apply 0.05 monthly.
 *
 * Note: The "5% per month" rule is applied directly in amortization — we store
 * the monthly rate as-is (0.05) and do NOT divide by 12 when computing payments.
 */
@Service
@Slf4j
public class LoanEligibilityService {

    /** Loan-to-balance ratio: borrow up to 10% of account balance */
    public static final BigDecimal MAX_LOAN_RATIO = new BigDecimal("0.10");

    /** Processing fee rate: 4% of loan principal */
    public static final BigDecimal PROCESSING_FEE_RATE = new BigDecimal("0.04");

    /** Fixed monthly interest rate: 5% per month */
    public static final BigDecimal MONTHLY_INTEREST_RATE = new BigDecimal("0.05");

    // ── Max loan calculation ─────────────────────────────────────────────────

    /**
     * Returns the maximum amount this account is eligible to borrow.
     * max = floor(balance × 10%)  rounded to 2 decimal places.
     */
    public BigDecimal maxLoanAmount(BigDecimal accountBalance) {
        return accountBalance.multiply(MAX_LOAN_RATIO).setScale(2, RoundingMode.FLOOR);
    }

    /**
     * Throws IllegalStateException if the requested amount exceeds the eligibility limit.
     */
    public void assertEligible(BigDecimal requestedAmount, BigDecimal accountBalance) {
        BigDecimal maxAllowed = maxLoanAmount(accountBalance);
        log.info("📊 Eligibility check — balance={} maxLoan={} requested={}",
                accountBalance, maxAllowed, requestedAmount);

        if (requestedAmount.compareTo(maxAllowed) > 0) {
            throw new IllegalStateException(String.format(
                    "Loan amount $%.2f exceeds your eligibility limit of $%.2f " +
                    "(max 10%% of your account balance $%.2f).",
                    requestedAmount, maxAllowed, accountBalance));
        }
    }

    // ── Processing fee ───────────────────────────────────────────────────────

    /**
     * Returns the one-time processing fee = 4% of loan principal.
     * Example: loan $1,000 → fee $40.00
     */
    public BigDecimal processingFee(BigDecimal loanAmount) {
        return loanAmount.multiply(PROCESSING_FEE_RATE).setScale(2, RoundingMode.HALF_UP);
    }

    // ── Monthly payment calculation (5% per month) ───────────────────────────

    /**
     * Calculates fixed monthly payment using the standard amortization formula.
     * Monthly rate r = 0.05 (5% per month, applied directly — NOT divided by 12).
     *
     *   M = P × [r(1+r)^n] / [(1+r)^n − 1]
     *
     * Example: $1,000 loan over 12 months at 5%/month
     *   M ≈ $112.83 / month
     */
    public BigDecimal monthlyPayment(BigDecimal principal, int termMonths) {
        BigDecimal r = MONTHLY_INTEREST_RATE;               // 0.05
        BigDecimal onePlusR = BigDecimal.ONE.add(r);        // 1.05
        BigDecimal onePlusRPowN = onePlusR.pow(termMonths); // 1.05^n

        BigDecimal numerator = principal.multiply(r).multiply(onePlusRPowN);
        BigDecimal denominator = onePlusRPowN.subtract(BigDecimal.ONE);
        return numerator.divide(denominator, 2, RoundingMode.HALF_UP);
    }
}
