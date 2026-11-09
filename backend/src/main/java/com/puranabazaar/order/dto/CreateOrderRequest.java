package com.puranabazaar.order.dto;

import com.puranabazaar.order.PaymentMethod;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateOrderRequest(
        @NotNull Long addressId,
        @NotNull PaymentMethod paymentMethod,
        @NotBlank @Size(min = 8, max = 80) String idempotencyKey,
        @Size(max = 500) String customerNote
) {
}
