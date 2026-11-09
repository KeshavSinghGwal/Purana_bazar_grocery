package com.puranabazaar.admin.dto;

import java.time.Instant;

public record AdminCustomerResponse(
        Long id,
        String name,
        String email,
        String phone,
        boolean active,
        Instant createdAt,
        long orderCount
) {
}
