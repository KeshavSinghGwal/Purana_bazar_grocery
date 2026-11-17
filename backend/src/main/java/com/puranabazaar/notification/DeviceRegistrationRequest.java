package com.puranabazaar.notification;

import jakarta.validation.constraints.NotBlank;

public record DeviceRegistrationRequest(
        @NotBlank String token,
        String platform
) {
}
