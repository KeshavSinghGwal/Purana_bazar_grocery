package com.puranabazaar.auth.dto;

import java.time.Instant;

public record UserResponse(
        Long id,
        String name,
        String email,
        String phone,
        String role,
        boolean active,
        Instant createdAt
) {
}
