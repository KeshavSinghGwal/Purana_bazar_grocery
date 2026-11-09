package com.puranabazaar.inventory.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record InventoryRequest(
        @NotNull Long productId,
        @NotNull @DecimalMin("0.01") @Digits(integer = 8, fraction = 2) BigDecimal price,
        @NotNull @Min(0) @Max(100000) Integer availableQuantity,
        Boolean active
) {
}
