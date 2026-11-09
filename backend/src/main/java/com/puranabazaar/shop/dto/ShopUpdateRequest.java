package com.puranabazaar.shop.dto;

import jakarta.validation.constraints.*;

import java.time.LocalTime;

public record ShopUpdateRequest(
        @Size(max = 150) String name,
        @Size(max = 2000) String description,
        @Size(max = 400) String address,
        @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        LocalTime openingTime,
        LocalTime closingTime,
        @DecimalMin("0.5") @DecimalMax("50.0") Double deliveryRadius,
        Boolean deliveryAvailable,
        @Min(5) @Max(240) Integer estimatedDeliveryMinutes,
        @Size(max = 80) String shopCategory,
        @Size(max = 500) String imageUrl,
        @Size(max = 20) String phone
) {
}
