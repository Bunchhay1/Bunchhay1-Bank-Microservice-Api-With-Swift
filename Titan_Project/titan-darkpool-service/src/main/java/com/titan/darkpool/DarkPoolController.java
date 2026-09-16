package com.titan.darkpool;

import org.springframework.web.bind.annotation.*;
import lombok.RequiredArgsConstructor;
import java.util.*;

@RestController
@RequestMapping("/api/v1/darkpool")
@RequiredArgsConstructor
public class DarkPoolController {
    private final MatchingEngine engine;
    
    @PostMapping("/order")
    public Map<String, Object> submitOrder(@RequestBody DarkPoolOrder order) {
        var result = engine.submitOrder(order);
        
        return Map.of(
            "orderId", order.getOrderId(),
            "matched", result.matched(),
            "matchId", result.matchId() != null ? result.matchId() : "PENDING",
            "status", result.matched() ? "EXECUTED" : "PENDING"
        );
    }
    
    @GetMapping("/matches")
    public List<MatchingEngine.Match> getMatches() {
        return engine.getExecutedMatches();
    }
    
    @GetMapping("/orderbook")
    public Map<String, Integer> getOrderBook() {
        return engine.getOrderBookDepth();
    }
}
