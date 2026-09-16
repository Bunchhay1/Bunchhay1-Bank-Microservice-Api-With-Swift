package com.titan.loans.service;

import com.titan.loans.client.CoreBankingClient;
import com.titan.loans.dto.LoanApplicationRequest;
import com.titan.loans.dto.LoanApprovalResponse;
import com.titan.loans.dto.LoanResponse;
import com.titan.loans.dto.RepaymentResponse;
import com.titan.loans.enums.LoanStatus;
import com.titan.loans.exception.LoanNotFoundException;
import com.titan.loans.model.Loan;
import com.titan.loans.model.LoanRepayment;
import com.titan.loans.repository.LoanRepaymentRepository;
import com.titan.loans.repository.LoanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class LoanService {

    private final LoanRepository loanRepository;
    private final LoanRepaymentRepository loanRepaymentRepository;
    private final LoanEligibilityService eligibilityService;
    private final CoreBankingClient coreBankingClient;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    // ─── Apply ───────────────────────────────────────────────────────────────

    @Transactional
    public LoanResponse apply(LoanApplicationRequest request, String username, String bearerToken) {
        // 1. Fetch account balance from core-banking
        Map<String, Object> account = coreBankingClient.getAccount(request.getAccountId(), bearerToken);
        BigDecimal balance = new BigDecimal(account.get("balance").toString());

        // 2. Eligibility: max = 10% of balance
        eligibilityService.assertEligible(request.getAmount(), balance);

        // 3. Pre-calculate fee and monthly payment
        BigDecimal processingFee   = eligibilityService.processingFee(request.getAmount());
        BigDecimal monthlyPayment  = eligibilityService.monthlyPayment(request.getAmount(), request.getTermMonths());

        log.info("📋 Loan eligibility OK — balance={} max={} requested={} fee={} monthly={}",
                balance, eligibilityService.maxLoanAmount(balance),
                request.getAmount(), processingFee, monthlyPayment);

        // 4. Save as PENDING
        Loan loan = Loan.builder()
                .accountId(request.getAccountId())
                .accountNumber(request.getAccountNumber())
                .username(username)
                .amount(request.getAmount())
                .interestRate(LoanEligibilityService.MONTHLY_INTEREST_RATE)
                .termMonths(request.getTermMonths())
                .processingFee(processingFee)
                .status(LoanStatus.PENDING)
                .note(request.getNote())
                .appliedAt(LocalDateTime.now())
                .build();

        Loan saved = loanRepository.save(loan);
        log.info("📋 Loan PENDING — id={} username={} amount={} fee={}", saved.getId(), username, request.getAmount(), processingFee);

        publishLoanEvent("banking.loans.applied", Map.of(
                "loanId", saved.getId(),
                "username", username,
                "amount", request.getAmount(),
                "processingFee", processingFee,
                "monthlyPayment", monthlyPayment,
                "status", "PENDING"
        ));

        return toResponse(saved, monthlyPayment);
    }

    // ─── Approve ─────────────────────────────────────────────────────────────

    @Transactional
    public LoanApprovalResponse approve(Long loanId, String bearerToken) {
        Loan loan = loanRepository.findById(loanId)
                .orElseThrow(() -> new LoanNotFoundException("Loan not found: " + loanId));

        if (loan.getStatus() != LoanStatus.PENDING) {
            throw new IllegalStateException("Only PENDING loans can be approved. Current: " + loan.getStatus());
        }

        loan.setStatus(LoanStatus.APPROVED);
        loan.setApprovedAt(LocalDateTime.now());
        loanRepository.save(loan);

        // Deduct 4% fee from borrower's account
        String feeReason = String.format("Processing fee for Loan #%d (4%% of $%.2f)", loanId, loan.getAmount());
        try {
            coreBankingClient.deductFee(loan.getAccountId(), loan.getProcessingFee(), feeReason, bearerToken);
            log.info("💳 Fee ${} deducted from account {} for loan {}", loan.getProcessingFee(), loan.getAccountId(), loanId);
        } catch (Exception e) {
            log.warn("⚠️ Fee deduction failed for loan {} (non-blocking): {}", loanId, e.getMessage());
        }

        // Credit the loan principal to the borrower's account
        String disbursementReason = String.format("Loan disbursement #%d — $%.2f approved", loanId, loan.getAmount());
        try {
            Map<String, Object> disburseResult = coreBankingClient.disburseLoan(
                    loan.getAccountId(), loan.getAmount(), disbursementReason, bearerToken);
            log.info("💰 Loan ${} disbursed to account {} — new balance={}",
                    loan.getAmount(), loan.getAccountId(), disburseResult.get("newBalance"));
        } catch (Exception e) {
            log.error("❌ Loan disbursement FAILED for loan {} — rolling back approval: {}", loanId, e.getMessage());
            loan.setStatus(LoanStatus.PENDING);
            loanRepository.save(loan);
            throw new IllegalStateException("Loan disbursement failed: " + e.getMessage());
        }

        // Generate amortization schedule at 5%/month
        List<LoanRepayment> schedule = generateAmortizationSchedule(loan);

        log.info("✅ Loan {} APPROVED — monthly=${} × {} months, fee={}",
                loanId,
                schedule.isEmpty() ? 0 : schedule.get(0).getAmount(),
                schedule.size(),
                loan.getProcessingFee());

        publishLoanEvent("banking.loans.approved", Map.of(
                "loanId", loanId,
                "username", loan.getUsername(),
                "amount", loan.getAmount(),
                "processingFee", loan.getProcessingFee(),
                "termMonths", loan.getTermMonths(),
                "monthlyPayment", schedule.isEmpty() ? 0 : schedule.get(0).getAmount(),
                "status", "APPROVED"
        ));

        return LoanApprovalResponse.builder()
                .message("Loan approved successfully")
                .loanId(loanId)
                .monthlyPayment(schedule.isEmpty() ? BigDecimal.ZERO : schedule.get(0).getAmount())
                .processingFee(loan.getProcessingFee())
                .totalRepayments(schedule.size())
                .build();
    }

    // ─── Reject ──────────────────────────────────────────────────────────────

    @Transactional
    public LoanResponse reject(Long loanId) {
        Loan loan = loanRepository.findById(loanId)
                .orElseThrow(() -> new LoanNotFoundException("Loan not found: " + loanId));

        if (loan.getStatus() != LoanStatus.PENDING) {
            throw new IllegalStateException("Only PENDING loans can be rejected. Current: " + loan.getStatus());
        }

        loan.setStatus(LoanStatus.REJECTED);
        loan.setRejectedAt(LocalDateTime.now());
        loanRepository.save(loan);

        log.info("❌ Loan {} REJECTED", loanId);

        publishLoanEvent("banking.loans.rejected", Map.of(
                "loanId", loanId,
                "username", loan.getUsername(),
                "status", "REJECTED"
        ));

        return toResponse(loan, eligibilityService.monthlyPayment(loan.getAmount(), loan.getTermMonths()));
    }

    // ─── Queries ─────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public LoanResponse getById(Long loanId) {
        Loan loan = loanRepository.findById(loanId)
                .orElseThrow(() -> new LoanNotFoundException("Loan not found: " + loanId));
        return toResponse(loan, eligibilityService.monthlyPayment(loan.getAmount(), loan.getTermMonths()));
    }

    @Transactional(readOnly = true)
    public List<LoanResponse> getByUsername(String username) {
        return loanRepository.findByUsername(username).stream()
                .map(l -> toResponse(l, eligibilityService.monthlyPayment(l.getAmount(), l.getTermMonths())))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<LoanResponse> getByAccountId(Long accountId) {
        return loanRepository.findByAccountId(accountId).stream()
                .map(l -> toResponse(l, eligibilityService.monthlyPayment(l.getAmount(), l.getTermMonths())))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<RepaymentResponse> getRepaymentSchedule(Long loanId) {
        if (!loanRepository.existsById(loanId)) {
            throw new LoanNotFoundException("Loan not found: " + loanId);
        }
        return loanRepaymentRepository.findByLoanId(loanId).stream()
                .map(this::toRepaymentResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<LoanResponse> getAll() {
        return loanRepository.findAll().stream()
                .map(l -> toResponse(l, eligibilityService.monthlyPayment(l.getAmount(), l.getTermMonths())))
                .collect(Collectors.toList());
    }

    // ─── Amortization (5%/month) ─────────────────────────────────────────────

    private List<LoanRepayment> generateAmortizationSchedule(Loan loan) {
        int n = loan.getTermMonths();
        BigDecimal monthlyPayment = eligibilityService.monthlyPayment(loan.getAmount(), n);

        List<LoanRepayment> schedule = new ArrayList<>();
        LocalDateTime dueDate = LocalDateTime.now().plusMonths(1);

        for (int i = 0; i < n; i++) {
            schedule.add(LoanRepayment.builder()
                    .loan(loan)
                    .dueDate(dueDate)
                    .amount(monthlyPayment)
                    .status("PENDING")
                    .build());
            dueDate = dueDate.plusMonths(1);
        }

        loanRepaymentRepository.saveAll(schedule);
        log.info("📅 Generated {} instalments of ${} for loan id={}", n, monthlyPayment, loan.getId());
        return schedule;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private void publishLoanEvent(String topic, Object payload) {
        try {
            kafkaTemplate.send(topic, payload);
        } catch (Exception e) {
            log.warn("⚠️ Kafka publish failed '{}': {}", topic, e.getMessage());
        }
    }

    private LoanResponse toResponse(Loan loan, BigDecimal monthlyPayment) {
        return LoanResponse.builder()
                .id(loan.getId())
                .accountId(loan.getAccountId())
                .accountNumber(loan.getAccountNumber())
                .username(loan.getUsername())
                .amount(loan.getAmount())
                .interestRate(loan.getInterestRate())
                .termMonths(loan.getTermMonths())
                .monthlyPayment(monthlyPayment)
                .processingFee(loan.getProcessingFee())
                .status(loan.getStatus().name())
                .note(loan.getNote())
                .appliedAt(loan.getAppliedAt())
                .approvedAt(loan.getApprovedAt())
                .rejectedAt(loan.getRejectedAt())
                .build();
    }

    private RepaymentResponse toRepaymentResponse(LoanRepayment r) {
        return RepaymentResponse.builder()
                .id(r.getId())
                .loanId(r.getLoan().getId())
                .dueDate(r.getDueDate())
                .amount(r.getAmount())
                .status(r.getStatus())
                .paidDate(r.getPaidDate())
                .build();
    }
}
