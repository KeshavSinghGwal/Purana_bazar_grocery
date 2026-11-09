package com.puranabazaar.shop.dto;

import java.time.Instant;
import java.time.LocalTime;

public record ShopResponse(
        Long id,
        Long ownerId,
        String ownerName,
        String name,
        String description,
        String address,
        double latitude,
        double longitude,
        LocalTime openingTime,
        LocalTime closingTime,
        double deliveryRadius,
        boolean deliveryAvailable,
        int estimatedDeliveryMinutes,
        String approvalStatus,
        String operationalStatus,
        String shopCategory,
        String imageUrl,
        String phone,
        Double distanceKm,
        boolean deliverable,
        boolean openNow,
        Double rating,
        long reviewCount,
        String rejectionReason,
        Instant createdAt
) {
}
