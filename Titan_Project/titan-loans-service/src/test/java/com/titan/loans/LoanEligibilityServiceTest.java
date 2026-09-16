package com.titan.loans;

import com.titan.loans.service.LoanEligibilityService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.*;

/**
 * Unit tests for LoanEligibilityService.
 *
 * Business rules under test:
 *  1. Max loan = 10% of account balance
 *  2. Processing fee = 4% of loan principal
 *  3. Monthly payment at 5% per month (standard amortization formula)
 */
class LoanEligibilityServiceTest {

    private final LoanEligibilityService svc = new LoanEligibilityService();

    // ── Rule 1: Max Loan Amount ───────────────────────────────────────────────

    @Test
    @DisplayName("balance $1,000 → max loan $100.00")
    void maxLoan_1000balance() {
        BigDecimal max = svc.maxLoanAmount(new BigDecimal("1000.00"));
        assertThat(max).isEqualByComparingTo(new BigDecimal("100.00"));
    }

    @Test
    @DisplayName("balance $10,000 → max loan $1,000.00")
    void maxLoan_10000balance() {
        BigDecimal max = svc.maxLoanAmount(new BigDecimal("10000.00"));
        assertThat(max).isEqualByComparingTo(new BigDecimal("1000.00"));
    }

    @Test
    @DisplayName("balance $500 → max loan $50.00")
    void maxLoan_500balance() {
        BigDecimal max = svc.maxLoanAmount(new BigDecimal("500.00"));
        assertThat(max).isEqualByComparingTo(new BigDecimal("50.00"));
    }

    @Test
    @DisplayName("balance $50,000 → max loan $5,000.00")
    void maxLoan_50000balance() {
        BigDecimal max = svc.maxLoanAmount(new BigDecimal("50000.00"));
        assertThat(max).isEqualByComparingTo(new BigDecimal("5000.00"));
    }

    // ── Rule 1: Eligibility check passes ─────────────────────────────────────

    @Test
    @DisplayName("requesting $100 with $1,000 balance → eligible")
    void eligible_exactLimit() {
        assertThatNoException()
                .isThrownBy(() -> svc.assertEligible(new BigDecimal("100.00"), new BigDecimal("1000.00")));
    }

    @Test
    @DisplayName("requesting $99 with $1,000 balance → eligible")
    void eligible_belowLimit() {
        assertThatNoException()
                .isThrownBy(() -> svc.assertEligible(new BigDecimal("99.00"), new BigDecimal("1000.00")));
    }

    // ── Rule 1: Eligibility check fails ──────────────────────────────────────

    @Test
    @DisplayName("requesting $101 with $1,000 balance → rejected")
    void ineligible_overLimit() {
        assertThatThrownBy(() -> svc.assertEligible(new BigDecimal("101.00"), new BigDecimal("1000.00")))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("eligibility limit");
    }

    @Test
    @DisplayName("requesting $1,001 with $10,000 balance → rejected")
    void ineligible_slightlyOver() {
        assertThatThrownBy(() -> svc.assertEligible(new BigDecimal("1001.00"), new BigDecimal("10000.00")))
                .isInstanceOf(IllegalStateException.class);
    }

    // ── Rule 2: Processing Fee (4%) ───────────────────────────────────────────

    @Test
    @DisplayName("loan $100 → fee $4.00")
    void processingFee_100() {
        BigDecimal fee = svc.processingFee(new BigDecimal("100.00"));
        assertThat(fee).isEqualByComparingTo(new BigDecimal("4.00"));
    }

    @Test
    @DisplayName("loan $1,000 → fee $40.00")
    void processingFee_1000() {
        BigDecimal fee = svc.processingFee(new BigDecimal("1000.00"));
        assertThat(fee).isEqualByComparingTo(new BigDecimal("40.00"));
    }

    @Test
    @DisplayName("loan $5,000 → fee $200.00")
    void processingFee_5000() {
        BigDecimal fee = svc.processingFee(new BigDecimal("5000.00"));
        assertThat(fee).isEqualByComparingTo(new BigDecimal("200.00"));
    }

    // ── Rule 3: Monthly Payment at 5%/month ───────────────────────────────────

    @Test
    @DisplayName("$1,000 over 12 months at 5%/month → ~$112.83/month")
    void monthlyPayment_1000_12months() {
        BigDecimal payment = svc.monthlyPayment(new BigDecimal("1000.00"), 12);
        // M = 1000 × [0.05 × 1.05^12] / [1.05^12 − 1] ≈ 112.83
        assertThat(payment).isBetween(new BigDecimal("112.00"), new BigDecimal("114.00"));
    }

    @Test
    @DisplayName("$100 over 12 months at 5%/month → ~$11.28/month")
    void monthlyPayment_100_12months() {
        BigDecimal payment = svc.monthlyPayment(new BigDecimal("100.00"), 12);
        assertThat(payment).isBetween(new BigDecimal("11.00"), new BigDecimal("12.00"));
    }

    @Test
    @DisplayName("$1,000 over 1 month → $1,050.00 (principal + one month interest)")
    void monthlyPayment_1000_1month() {
        BigDecimal payment = svc.monthlyPayment(new BigDecimal("1000.00"), 1);
        // For 1-month term: M = 1000 × 0.05 × 1.05 / (1.05 - 1) = 1050
        assertThat(payment).isEqualByComparingTo(new BigDecimal("1050.00"));
    }

    // ── End-to-end scenario ───────────────────────────────────────────────────

    @Test
    @DisplayName("scenario: $10,000 balance, borrow $1,000 for 12 months")
    void scenario_10k_balance_borrow_1000() {
        BigDecimal balance = new BigDecimal("10000.00");
        BigDecimal loanAmount = new BigDecimal("1000.00");
        int termMonths = 12;

        // Eligible?
        assertThatNoException().isThrownBy(() -> svc.assertEligible(loanAmount, balance));

        // Fee = $40
        BigDecimal fee = svc.processingFee(loanAmount);
        assertThat(fee).isEqualByComparingTo(new BigDecimal("40.00"));

        // Monthly ~$112.83
        BigDecimal mp = svc.monthlyPayment(loanAmount, termMonths);
        assertThat(mp).isBetween(new BigDecimal("112.00"), new BigDecimal("114.00"));

        // Total repaid
        BigDecimal totalRepaid = mp.multiply(new BigDecimal(termMonths));
        // Should be more than principal (interest charged)
        assertThat(totalRepaid).isGreaterThan(loanAmount);
    }
}
