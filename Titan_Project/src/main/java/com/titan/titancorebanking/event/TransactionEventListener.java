package com.titan.titancorebanking.event;

import com.titan.titancorebanking.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
public class TransactionEventListener {

    private final NotificationService notificationService;

    @Async // ⚡ Run in a separate thread (Non-Blocking)
    @EventListener // 👂 Listen for TransactionEvent
    public void handleTransactionEvent(TransactionEvent event) {

        log.info("📨 Event Received: Sending notification to {} for ${}...", event.getUsername(), event.getAmount());

        // Simulate a slow email server (to prove it's async)
        // In real life, we don't need Thread.sleep, but this proves the user doesn't wait!
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // Call the original Notification Logic
        notificationService.sendNotification(event.getUsername(), event.getMessage());

        log.info("✅ Notification Sent Async!");
    }
}