package com.titan.titancorebanking.service.imple;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@Slf4j
public class OtpService {

    // Simple in-memory storage for OTPs (Username -> OTP)
    // In production, use Redis!
    private final Map<String, String> otpStorage = new ConcurrentHashMap<>();

    public void generateOtp(String username) {
        String otp = "123456"; // Hardcoded for testing simplicity
        otpStorage.put(username, otp);
        log.info("🔐 OTP Generated for [{}]: {}", username, otp);
    }

    public void validateOtp(String username, String otp) {
        // For testing purposes, accept "123456" or the stored OTP
        String storedOtp = otpStorage.getOrDefault(username, "123456");

        if (!storedOtp.equals(otp)) {
            throw new IllegalArgumentException("❌ Invalid OTP!");
        }

        // Clear OTP after successful use
        otpStorage.remove(username);
        log.info("✅ OTP Validated for [{}]", username);
    }
}