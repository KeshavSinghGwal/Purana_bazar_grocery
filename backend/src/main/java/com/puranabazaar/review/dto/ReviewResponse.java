package com.puranabazaar.review.dto;

import jakarta.validation.constraints.*;

import java.time.Instant;

public record ReviewResponse(
        Long id,
        Long customerId,
        String customerName,
        int rating,
        String comment,
        Instant createdAt
) {
}
