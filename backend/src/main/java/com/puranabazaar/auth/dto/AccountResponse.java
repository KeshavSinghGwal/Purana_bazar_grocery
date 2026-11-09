package com.puranabazaar.auth.dto;

public record AccountResponse(
        UserResponse user,
        Long shopId,
        String shopStatus
) {
}
