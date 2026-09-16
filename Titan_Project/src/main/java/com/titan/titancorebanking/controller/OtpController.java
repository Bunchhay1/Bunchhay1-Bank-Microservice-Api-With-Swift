package com.titan.titancorebanking.controller;

import com.titan.titancorebanking.service.imple.OtpService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth/otp") // 👈 Path ដាច់ដោយឡែក
@RequiredArgsConstructor
public class OtpController {

    private final OtpService otpService;

    // ==========================================
    // 🔐 REQUEST OTP ENDPOINT
    // ==========================================
    @PostMapping("/generate")
    public ResponseEntity<?> generateOtp(Authentication authentication) {

        // 1. យក username ពី Token (User ដែលកំពុង Login)
        String username = authentication.getName();

        // 2. បង្កើត OTP (Save ចូល Redis & Log ចូល Console)
        otpService.generateOtp(username);

        // 3. ឆ្លើយតបទៅ Frontend
        return ResponseEntity.ok(Map.of(
                "message", "📧 OTP has been sent! (Check Server Console)",
                "status", "PENDING_VERIFICATION"
        ));
    }
}