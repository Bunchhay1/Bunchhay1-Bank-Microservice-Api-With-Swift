package com.titan.titancorebanking.controller;

import com.titan.titancorebanking.model.Account;
import com.titan.titancorebanking.model.Loan;
import com.titan.titancorebanking.repository.AccountRepository; // ✅ Need this
import com.titan.titancorebanking.repository.LoanRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/loans")
@RequiredArgsConstructor
public class LoanController {

    private final LoanRepository loanRepository;
    private final AccountRepository accountRepository; // ✅ Inject Repository

    @PostMapping("/apply")
    public ResponseEntity<?> apply(@RequestBody Map<String, Object> payload) {

        // 1. Find the Account first
        Long accountId = ((Number) payload.get("accountId")).longValue();
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Account not found"));

        // 2. Create Loan linked to Account
        Loan loan = Loan.builder()
                .account(account) // ✅ Set Object, not ID
                .amount(new BigDecimal(payload.get("amount").toString()))
                .interestRate(new BigDecimal(payload.getOrDefault("interestRate", "0.05").toString()))
                .termMonths((Integer) payload.getOrDefault("termMonths", 12))
                .status("PENDING")
                .build();

        return ResponseEntity.ok(loanRepository.save(loan));
    }

    @PutMapping("/{id}/approve")
    public ResponseEntity<?> approve(@PathVariable Long id) {
        Loan loan = loanRepository.findById(id).orElseThrow();
        loan.setStatus("APPROVED");

        // 💰 OPTIONAL: Disburse money to account immediately
        // loan.getAccount().setBalance(loan.getAccount().getBalance().add(loan.getAmount()));
        // accountRepository.save(loan.getAccount());

        return ResponseEntity.ok(java.util.Map.of("message", "Loan Approved Successfully", "loanId", id));
    }

}