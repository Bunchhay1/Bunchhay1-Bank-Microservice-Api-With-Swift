package com.titan.darkpool;

import org.springframework.stereotype.Service;
import java.util.concurrent.*;
import java.util.*;

@Service
public class MatchingEngine {
    private final ConcurrentHashMap<String, ConcurrentLinkedQueue<DarkPoolOrder>> orderBook = new ConcurrentHashMap<>();
    private final List<Match> executedMatches = new CopyOnWriteArrayList<>();
    
    public MatchResult submitOrder(DarkPoolOrder order) {
        // Try immediate match
        DarkPoolOrder counterparty = findMatch(order);
        
        if (counterparty != null) {
            Match match = executeMatch(order, counterparty);
            return new MatchResult(true, match.matchId, counterparty.getOrderId());
        }
        
        // Add to order book
        orderBook.computeIfAbsent(order.getPair(), k -> new ConcurrentLinkedQueue<>()).add(order);
        return new MatchResult(false, null, null);
    }
    
    private DarkPoolOrder findMatch(DarkPoolOrder incoming) {
        String reversePair = incoming.getReversePair();
        ConcurrentLinkedQueue<DarkPoolOrder> queue = orderBook.get(reversePair);
        
        if (queue == null) return null;
        
        for (DarkPoolOrder candidate : queue) {
            if (candidate.getAmount().compareTo(incoming.getAmount()) == 0 &&
                candidate.getSide() != incoming.getSide()) {
                queue.remove(candidate);
                return candidate;
            }
        }
        return null;
    }
    
    private Match executeMatch(DarkPoolOrder o1, DarkPoolOrder o2) {
        Match match = new Match(
            UUID.randomUUID().toString(),
            o1.getOrderId(),
            o2.getOrderId(),
            o1.getAmount(),
            o1.getPair()
        );
        executedMatches.add(match);
        System.out.println("✅ DARK POOL MATCH: " + match.matchId);
        return match;
    }
    
    public List<Match> getExecutedMatches() {
        return new ArrayList<>(executedMatches);
    }
    
    public Map<String, Integer> getOrderBookDepth() {
        Map<String, Integer> depth = new HashMap<>();
        orderBook.forEach((pair, queue) -> depth.put(pair, queue.size()));
        return depth;
    }
    
    record Match(String matchId, String order1Id, String order2Id, 
                 java.math.BigDecimal amount, String pair) {}
    
    record MatchResult(boolean matched, String matchId, String counterpartyOrderId) {}
}
