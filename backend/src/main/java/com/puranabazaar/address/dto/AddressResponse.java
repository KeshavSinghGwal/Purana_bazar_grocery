package com.puranabazaar.address.dto;

import java.time.Instant;

public record AddressResponse(
        Long id,
        String label,
        String addressLine,
        String city,
        String state,
        String postalCode,
        double latitude,
        double longitude,
        boolean isDefault,
        String formattedAddress,
        Instant createdAt
) {
}
