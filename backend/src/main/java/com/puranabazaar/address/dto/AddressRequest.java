package com.puranabazaar.address.dto;

import jakarta.validation.constraints.*;

public record AddressRequest(
        @Size(max = 60) String label,
        @NotBlank @Size(max = 400) String addressLine,
        @NotBlank @Size(max = 100) String city,
        @NotBlank @Size(max = 100) String state,
        @NotBlank @Pattern(regexp = "^[0-9]{4,10}$", message = "Enter a valid postal code") String postalCode,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        Boolean isDefault
) {
}
