package com.titan.loans.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Map;

/**
 * HTTP client for titan-loans-service to call titan-core-banking APIs.
 * Used to:
 *  - Verify account balance (for loan eligibility)
 *  - Deduct processing fees (POST transaction)
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class CoreBankingClient {

    private final RestTemplate restTemplate;

    @Value("${titan.core-banking.url:http://titan-core-banking:8080}")
    private String coreBankingUrl;

    /**
     * GET /api/v1/accounts/{id} → { "id": 123, "balance": 5000.00, ... }
     */
    public Map<String, Object> getAccount(Long accountId, String bearerToken) {
        String url = coreBankingUrl + "/api/v1/accounts/" + accountId;
        log.info("🔗 [CoreBankingClient] GET {} — fetching account balance", url);

        try {
            ResponseEntity<Map<String, Object>> resp = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    new HttpEntity<>(headers(bearerToken)),
                    new ParameterizedTypeReference<>() {});
            return resp.getBody();
        } catch (HttpClientErrorException e) {
            log.warn("⚠️ [CoreBankingClient] HTTP {} from core-banking: {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new IllegalStateException("Unable to fetch account info: " + e.getStatusCode());
        } catch (Exception e) {
            log.error("❌ [CoreBankingClient] Cannot reach titan-core-banking: {}", e.getMessage());
            throw new IllegalStateException("Core banking service is currently unavailable");
        }
    }

    /**
     * POST /api/v1/transactions/internal/deduct-fee
     * Body: { "accountId": 123, "amount": 40.00, "reason": "Loan processing fee" }
     */
    public Map<String, Object> deductFee(Long accountId, BigDecimal feeAmount, String reason, String bearerToken) {
        String url = coreBankingUrl + "/api/v1/transactions/internal/deduct-fee";
        log.info("🔗 [CoreBankingClient] POST {} — deducting fee {} from account {}", url, feeAmount, accountId);

        Map<String, Object> body = Map.of(
                "accountId", accountId,
                "amount", feeAmount,
                "reason", reason != null ? reason : "Loan processing fee"
        );

        try {
            ResponseEntity<Map<String, Object>> resp = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    new HttpEntity<>(body, headers(bearerToken)),
                    new ParameterizedTypeReference<>() {});
            return resp.getBody();
        } catch (HttpClientErrorException e) {
            log.warn("⚠️ [CoreBankingClient] HTTP {} from core-banking: {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new IllegalStateException("Unable to deduct fee: " + e.getMessage());
        } catch (Exception e) {
            log.error("❌ [CoreBankingClient] Cannot reach titan-core-banking: {}", e.getMessage());
            throw new IllegalStateException("Core banking service is currently unavailable");
        }
    }

    /**
     * POST /api/v1/transactions/internal/disburse-loan
     * Body: { "accountId": 123, "amount": 10000.00, "reason": "Loan disbursement #1" }
     */
    public Map<String, Object> disburseLoan(Long accountId, BigDecimal amount, String reason, String bearerToken) {
        String url = coreBankingUrl + "/api/v1/transactions/internal/disburse-loan";
        log.info("🔗 [CoreBankingClient] POST {} — crediting loan {} to account {}", url, amount, accountId);

        Map<String, Object> body = Map.of(
                "accountId", accountId,
                "amount", amount,
                "reason", reason != null ? reason : "Loan disbursement"
        );

        try {
            ResponseEntity<Map<String, Object>> resp = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    new HttpEntity<>(body, headers(bearerToken)),
                    new ParameterizedTypeReference<>() {});
            return resp.getBody();
        } catch (HttpClientErrorException e) {
            log.warn("⚠️ [CoreBankingClient] HTTP {} from core-banking: {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new IllegalStateException("Unable to disburse loan: " + e.getMessage());
        } catch (Exception e) {
            log.error("❌ [CoreBankingClient] Cannot reach titan-core-banking: {}", e.getMessage());
            throw new IllegalStateException("Core banking service is currently unavailable");
        }
    }

    private HttpHeaders headers(String bearerToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (bearerToken != null && !bearerToken.isBlank()) {
            headers.setBearerAuth(
                    bearerToken.startsWith("Bearer ") ? bearerToken.substring(7) : bearerToken);
        }
        return headers;
    }
}
