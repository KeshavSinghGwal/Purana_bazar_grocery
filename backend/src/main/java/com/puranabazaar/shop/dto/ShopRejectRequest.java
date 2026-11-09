package com.puranabazaar.shop.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ShopRejectRequest(
        @NotBlank @Size(max = 500) String reason
) {
}
