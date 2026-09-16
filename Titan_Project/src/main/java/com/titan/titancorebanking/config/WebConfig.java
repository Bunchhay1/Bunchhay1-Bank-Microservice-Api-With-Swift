package com.titan.titancorebanking.config;

import com.titan.titancorebanking.interceptor.IdempotencyInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final IdempotencyInterceptor idempotencyInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // ដាក់ Idempotency លើគ្រប់ API ទាំងអស់ដែលហៅចូល /api/transactions/**
        registry.addInterceptor(idempotencyInterceptor)
                .addPathPatterns("/api/transactions/**");
    }
}