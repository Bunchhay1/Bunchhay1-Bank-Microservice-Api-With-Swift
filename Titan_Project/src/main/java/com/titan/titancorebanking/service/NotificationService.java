package com.titan.titancorebanking.service;

import com.titan.titancorebanking.dto.request.NotificationRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class NotificationService {

    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);
    private final RestClient restClient;
    private final String notificationUrl;

    // Constructor Injection: ទាញយក URL ពី application.properties (Default: http://localhost:8081)
    public NotificationService(RestClient.Builder builder,
                               @Value("${notification.service.url:http://localhost:8081}") String notificationUrl) {
        this.restClient = builder.build();
        this.notificationUrl = notificationUrl;
    }

    public void sendNotification(String userId, String message) {
        // បង្កើតកញ្ចប់ទិន្នន័យ
        NotificationRequest request = new NotificationRequest(userId, message);

        logger.info("📢 Calling Golang Service on port 8081 for user: {}", userId);

        try {
            // ហៅទៅ Golang (Fire and Forget - ផ្ញើចោល មិនបាច់ចាំចម្លើយ)
            restClient.post()
                    .uri(notificationUrl + "/api/notify")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .toBodilessEntity(); // Void response

            logger.info("✅ Notification Sent via Golang!");

        } catch (Exception e) {
            // បើ Golang ដាច់ភ្លើង កុំឲ្យ Java គាំង! គ្រាន់តែ Log Error ទុក
            logger.error("⚠️ Failed to send notification: {}", e.getMessage());
        }
    }
}