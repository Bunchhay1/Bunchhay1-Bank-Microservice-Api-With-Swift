package com.titan.titancorebanking.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

// ✅ នេះគឺជាចំណុចសំខាន់! យើងហៅកូដពី AI (Generated Code)
// កុំប្រើ import com.titan.titancorebanking.dto.request.RiskCheckRequest; (នោះជារបស់ Frontend)
import com.titan.riskengine.RiskCheckRequest;
import com.titan.riskengine.RiskCheckResponse;
import com.titan.riskengine.RiskEngineServiceGrpc;

@Slf4j
@Service
public class RiskEngineGrpcService {

    private final RiskEngineServiceGrpc.RiskEngineServiceBlockingStub riskStub;

    public RiskEngineGrpcService(RiskEngineServiceGrpc.RiskEngineServiceBlockingStub riskStub) {
        this.riskStub = riskStub;
    }

    // ✅ Method នេះហៅទៅ Python AI
    @CircuitBreaker(name = "risk-engine", fallbackMethod = "fallbackRiskCheck")
    public RiskCheckResponse analyzeTransaction(String userId, double amount) {
        log.info("📡 Calling Python AI for User: {}", userId);

        // បង្កើត Request សម្រាប់ AI (ប្រើកូដដែល Generate មក)
        RiskCheckRequest request = RiskCheckRequest.newBuilder()
                .setUserId(userId)
                .setAmount(amount)
                .build();

        // ផ្ញើទៅ Python
        return riskStub.checkRisk(request);
    }

    // 🛟 Fallback (ពេល Python ដាច់)
    public RiskCheckResponse fallbackRiskCheck(String userId, double amount, Throwable t) {
        log.error("⚠️ AI Service is DOWN! Reason: {}. Executing Fail-Open Strategy.", t.getMessage());

        // បង្កើតចម្លើយក្លែងក្លាយ (Allow ទាំងអស់)
        return RiskCheckResponse.newBuilder()
                .setRiskScore(0)
                .setRiskLevel("UNKNOWN")
                .setAction("ALLOW")
                .build();
    }
}