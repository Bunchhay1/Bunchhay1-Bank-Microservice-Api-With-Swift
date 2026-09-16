package com.titan.titancorebanking.controller;

import com.titan.titancorebanking.model.FixedDeposit;
import com.titan.titancorebanking.repository.FixedDepositRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/fixed-deposits")
@RequiredArgsConstructor
public class FixedDepositController {

    private final FixedDepositRepository repository;

    @PostMapping("/create")
    public ResponseEntity<?> create(@RequestBody Map<String, Object> payload) {
        Integer months = (Integer) payload.get("termMonths");
        FixedDeposit fd = FixedDeposit.builder()
                .accountId(((Number) payload.get("accountId")).longValue())
                .amount(new BigDecimal(payload.get("amount").toString()))
                .termMonths(months)
                .interestRate(new BigDecimal("0.06")) // Fixed 6% rate
                .maturityDate(LocalDateTime.now().plusMonths(months))
                .status("ACTIVE")
                .build();
        return ResponseEntity.ok(repository.save(fd));
    }
}