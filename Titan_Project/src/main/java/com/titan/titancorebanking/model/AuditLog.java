package com.titan.titancorebanking.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "audit_logs")
public class AuditLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String action;
    private String username;

    // ✅ Add missing fields for Aspect
    private String ipAddress;
    private String status;

    private String details;
    private LocalDateTime timestamp;
}