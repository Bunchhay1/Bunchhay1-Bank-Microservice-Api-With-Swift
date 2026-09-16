package com.titan.titancorebanking.controller;

import com.titan.titancorebanking.dto.request.TransactionRequest;
import com.titan.titancorebanking.model.Transaction;
import com.titan.titancorebanking.service.TransactionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/v1/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;

    // ✅ Task 2 & 8: Transfer (FX & Fees)
    @PostMapping("/transfer")
    public ResponseEntity<Transaction> transfer(
            @RequestBody TransactionRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok(transactionService.transfer(request, userDetails.getUsername()));
    }

    // ✅ Task 5: Withdraw (Overdraft)
    @PostMapping("/withdraw")
    public ResponseEntity<Transaction> withdraw(
            @RequestBody TransactionRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok(transactionService.withdraw(request, userDetails.getUsername()));
    }

    @PostMapping("/deposit")
    public ResponseEntity<Transaction> deposit(@RequestBody TransactionRequest request) {
        return ResponseEntity.ok(transactionService.deposit(request));
    }

    // ✅ Task 9: International Transfer (IBAN Validation)
    @PostMapping("/international")
    public ResponseEntity<?> internationalTransfer(
            @RequestBody TransactionRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        // Regex Validation Logic
        String swiftRegex = "^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$";
        String ibanRegex = "^[A-Z]{2}\\d{2}[A-Z0-9]{4,30}$";

        if (request.getSwiftCode() == null || !Pattern.matches(swiftRegex, request.getSwiftCode())) {
            return ResponseEntity.badRequest().body("❌ Invalid SWIFT Code");
        }
        if (request.getIban() == null || !Pattern.matches(ibanRegex, request.getIban())) {
            return ResponseEntity.badRequest().body("❌ Invalid IBAN Format");
        }

        // Mock Success for now (since we don't have real SWIFT integration)
        return ResponseEntity.ok("✅ International Transfer Initiated");
    }
}