package com.titan.loans.controller;

import com.titan.loans.dto.LoanApplicationRequest;
import com.titan.loans.dto.LoanApprovalResponse;
import com.titan.loans.dto.LoanResponse;
import com.titan.loans.dto.RepaymentResponse;
import com.titan.loans.service.LoanService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/loans")
@RequiredArgsConstructor
@Tag(name = "Loans", description = "Loan application, approval, and repayment APIs")
public class LoanController {

    private final LoanService loanService;

    // ── POST /api/v1/loans/apply ─────────────────────────────────────────────
    @PostMapping("/apply")
    @Operation(summary = "Apply for a new loan",
               description = "Eligibility: max loan = 10% of account balance. Fee: 4% charged on approval.")
    public ResponseEntity<LoanResponse> apply(
            @Valid @RequestBody LoanApplicationRequest request,
            Principal principal,
            HttpServletRequest httpRequest) {

        String username = principal != null ? principal.getName() : "anonymous";
        String token = extractToken(httpRequest);
        return ResponseEntity.ok(loanService.apply(request, username, token));
    }

    // ── PUT /api/v1/loans/{id}/approve ───────────────────────────────────────
    @PutMapping("/{id}/approve")
    @Operation(summary = "Approve a PENDING loan",
               description = "Deducts 4% processing fee from borrower's account and generates repayment schedule at 5%/month.")
    public ResponseEntity<LoanApprovalResponse> approve(
            @PathVariable Long id,
            HttpServletRequest httpRequest) {

        return ResponseEntity.ok(loanService.approve(id, extractToken(httpRequest)));
    }

    // ── PUT /api/v1/loans/{id}/reject ────────────────────────────────────────
    @PutMapping("/{id}/reject")
    @Operation(summary = "Reject a PENDING loan")
    public ResponseEntity<LoanResponse> reject(@PathVariable Long id) {
        return ResponseEntity.ok(loanService.reject(id));
    }

    // ── GET /api/v1/loans/{id} ───────────────────────────────────────────────
    @GetMapping("/{id}")
    @Operation(summary = "Get a loan by ID")
    public ResponseEntity<LoanResponse> getById(@PathVariable Long id) {
        return ResponseEntity.ok(loanService.getById(id));
    }

    // ── GET /api/v1/loans/my ─────────────────────────────────────────────────
    @GetMapping("/my")
    @Operation(summary = "Get all loans for the authenticated user")
    public ResponseEntity<List<LoanResponse>> myLoans(Principal principal) {
        String username = principal != null ? principal.getName() : "anonymous";
        return ResponseEntity.ok(loanService.getByUsername(username));
    }

    // ── GET /api/v1/loans/account/{accountId} ────────────────────────────────
    @GetMapping("/account/{accountId}")
    @Operation(summary = "Get loans by account ID")
    public ResponseEntity<List<LoanResponse>> getByAccount(@PathVariable Long accountId) {
        return ResponseEntity.ok(loanService.getByAccountId(accountId));
    }

    // ── GET /api/v1/loans/{id}/repayments ────────────────────────────────────
    @GetMapping("/{id}/repayments")
    @Operation(summary = "Get amortization schedule for a loan")
    public ResponseEntity<List<RepaymentResponse>> getRepaymentSchedule(@PathVariable Long id) {
        return ResponseEntity.ok(loanService.getRepaymentSchedule(id));
    }

    // ── GET /api/v1/loans (admin) ────────────────────────────────────────────
    @GetMapping
    @Operation(summary = "Get all loans (admin)")
    public ResponseEntity<List<LoanResponse>> getAll() {
        return ResponseEntity.ok(loanService.getAll());
    }

    // ── Internal health endpoint ──────────────────────────────────────────────
    @GetMapping("/internal/health")
    public ResponseEntity<Map<String, String>> internalHealth() {
        return ResponseEntity.ok(Map.of("status", "UP", "service", "titan-loans-service"));
    }

    private String extractToken(HttpServletRequest request) {
        String auth = request.getHeader("Authorization");
        return (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : null;
    }
}
