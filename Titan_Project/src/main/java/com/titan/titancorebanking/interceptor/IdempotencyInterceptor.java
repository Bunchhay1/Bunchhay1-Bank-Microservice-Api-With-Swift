package com.titan.titancorebanking.interceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.concurrent.TimeUnit;

@Component
@RequiredArgsConstructor
public class IdempotencyInterceptor implements HandlerInterceptor {

    private final StringRedisTemplate redisTemplate;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {

        // យើងការពារតែ Method POST ទេ (ដូចជា Transfer/Create)
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String key = request.getHeader("Idempotency-Key");
        if (key == null || key.isEmpty()) {
            return true; // បើអត់ដាក់ Key មក ឱ្យទៅតាមធម្មតា (ឬចង់ Block ក៏បាន)
        }

        String redisKey = "idempotency:" + key;

        // ឆែកមើលថា Key នេះធ្លាប់ប្រើឬនៅ?
        if (Boolean.TRUE.equals(redisTemplate.hasKey(redisKey))) {
            response.setStatus(HttpStatus.CONFLICT.value()); // 409 Conflict
            response.getWriter().write("{\"error\": \"Double Spending Detected! Request already processed.\"}");
            response.setContentType("application/json");
            return false; // ⛔ បិទផ្លូវ!
        }

        // Save Key ទុក ២៤ ម៉ោង
        redisTemplate.opsForValue().set(redisKey, "PROCESSED", 24, TimeUnit.HOURS);
        return true; // ✅ បើកផ្លូវ
    }
}