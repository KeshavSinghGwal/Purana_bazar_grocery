package com.puranabazaar.auth.dto;

public record AuthResponse(
        String token,
        String tokenType,
        long expiresInMinutes,
        UserResponse user,
        Long shopId,
        String shopStatus
) {
    public static AuthResponse of(String token, long expiresInMinutes, UserResponse user) {
        return new AuthResponse(token, "Bearer", expiresInMinutes, user, null, null);
    }
}
