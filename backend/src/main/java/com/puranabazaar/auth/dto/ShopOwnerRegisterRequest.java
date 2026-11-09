package com.puranabazaar.auth.dto;

import jakarta.validation.constraints.*;

import java.time.LocalTime;

public record ShopOwnerRegisterRequest(
        @NotBlank @Size(min = 2, max = 120) String name,
        @NotBlank @Email @Size(max = 190) String email,
        @NotBlank @Pattern(regexp = "^[0-9+\\- ]{8,20}$", message = "Enter a valid phone number") String phone,
        @NotBlank @Size(min = 8, max = 72) String password,

        @NotBlank @Size(max = 150) String shopName,
        @Size(max = 2000) String description,
        @NotBlank @Size(max = 400) String address,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        @NotNull LocalTime openingTime,
        @NotNull LocalTime closingTime,
        @NotNull @DecimalMin("0.5") @DecimalMax("50.0") Double deliveryRadius,
        @Size(max = 80) String shopCategory,
        @Size(max = 500) String imageUrl,
        @Size(max = 20) String shopPhone
) {
}
