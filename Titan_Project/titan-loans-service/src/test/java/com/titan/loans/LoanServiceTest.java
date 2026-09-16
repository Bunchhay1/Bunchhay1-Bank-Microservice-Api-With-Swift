package com.titan.loans;

import com.titan.loans.client.CoreBankingClient;
import com.titan.loans.dto.LoanApprovalResponse;
import com.titan.loans.enums.LoanStatus;
import com.titan.loans.model.Loan;
import com.titan.loans.repository.LoanRepaymentRepository;
import com.titan.loans.repository.LoanRepository;
import com.titan.loans.service.LoanEligibilityService;
import com.titan.loans.service.LoanService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LoanServiceTest {

    @Mock
    private LoanRepository loanRepository;

    @Mock
    private LoanRepaymentRepository loanRepaymentRepository;

    @Mock
    private LoanEligibilityService eligibilityService;

    @Mock
    private CoreBankingClient coreBankingClient;

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @InjectMocks
    private LoanService loanService;

    @Test
    @DisplayName("Should approve loan, deduct fee, and disburse principal when all systems are healthy")
    void approve_SuccessScenario() {
        // Arrange
        Long loanId = 1L;
        String token = "bearer-token";
        Loan loan = Loan.builder()
                .id(loanId)
                .accountId(10L)
                .amount(new BigDecimal("1000.00"))
                .processingFee(new BigDecimal("40.00"))
                .termMonths(12)
                .status(LoanStatus.PENDING)
                .username("alice")
                .build();

        when(loanRepository.findById(loanId)).thenReturn(Optional.of(loan));
        when(eligibilityService.monthlyPayment(any(), anyInt())).thenReturn(new BigDecimal("112.83"));

        // Act
        LoanApprovalResponse response = loanService.approve(loanId, token);

        // Assert
        assertThat(response).isNotNull();
        assertThat(response.getLoanId()).isEqualTo(loanId);
        assertThat(loan.getStatus()).isEqualTo(LoanStatus.APPROVED);

        // Verify fee deduction and disbursement were both called
        verify(coreBankingClient).deductFee(eq(10L), eq(new BigDecimal("40.00")), anyString(), eq(token));
        verify(coreBankingClient).disburseLoan(eq(10L), eq(new BigDecimal("1000.00")), anyString(), eq(token));
        verify(loanRepository, times(2)).save(loan); // saved once at start of approve, once after status update
    }

    @Test
    @DisplayName("🔴 BUG DEMONSTRATION: Failed disbursement leaves borrower charged with fee (Distributed Transaction inconsistency)")
    void approve_ShouldFailAndLeaveInconsistentState_WhenDisbursementFailsAfterFeeDeduction() {
        // Arrange
        Long loanId = 1L;
        String token = "bearer-token";
        Loan loan = Loan.builder()
                .id(loanId)
                .accountId(10L)
                .amount(new BigDecimal("1000.00"))
                .processingFee(new BigDecimal("40.00"))
                .termMonths(12)
                .status(LoanStatus.PENDING)
                .username("alice")
                .build();

        when(loanRepository.findById(loanId)).thenReturn(Optional.of(loan));

        // Mock Fee Deduction: SUCCESS
        doNothing().when(coreBankingClient).deductFee(eq(10L), eq(new BigDecimal("40.00")), anyString(), eq(token));

        // Mock Disbursement: FAILED (Simulates downstream core-banking crash or timeout)
        when(coreBankingClient.disburseLoan(eq(10L), eq(new BigDecimal("1000.00")), anyString(), eq(token)))
                .thenThrow(new RuntimeException("Core Banking Connection Timeout"));

        // Act & Assert
        assertThatThrownBy(() -> loanService.approve(loanId, token))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Loan disbursement failed");

        // Verify the loan state rolled back to PENDING (correct local behavior)
        assertThat(loan.getStatus()).isEqualTo(LoanStatus.PENDING);

        // 🔴 BUG PROOF: Fee was successfully deducted, but no refund method was ever called!
        verify(coreBankingClient).deductFee(eq(10L), eq(new BigDecimal("40.00")), anyString(), eq(token));
        verify(coreBankingClient).disburseLoan(eq(10L), eq(new BigDecimal("1000.00")), anyString(), eq(token));
        
        // Assert that NO compensating/refund transaction was executed
        verify(coreBankingClient, never()).deductFee(eq(10L), eq(new BigDecimal("-40.00")), anyString(), eq(token));
        // (Note: coreBankingClient doesn't even expose a refundFee method, proving the architectural gap)
    }
}
