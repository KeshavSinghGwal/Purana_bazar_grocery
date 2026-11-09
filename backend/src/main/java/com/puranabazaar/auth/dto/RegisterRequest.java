package com.puranabazaar.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank @Size(min = 2, max = 120) String name,
        @NotBlank @Email @Size(max = 190) String email,
        @Pattern(regexp = "^$|^[0-9+\\- ]{8,20}$", message = "Enter a valid phone number") String phone,
        @NotBlank @Size(min = 8, max = 72, message = "Password must be 8-72 characters") String password
) {
}
