package com.puranabazaar.cart.dto;

import com.puranabazaar.cart.ShoppingMode;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record AddCartItemRequest(
        @NotNull ShoppingMode shoppingMode,
        Long productId,
        Long shopInventoryId,
        @NotNull @Min(1) @Max(99) Integer quantity
) {
}
