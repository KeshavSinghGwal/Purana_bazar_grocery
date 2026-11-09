package com.puranabazaar.marketplace.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record FindShopRequest(
        @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        Long addressId,
        @Valid List<FindShopLine> items
) {
    public record FindShopLine(@NotNull Long productId, @NotNull @Min(1) Integer quantity) {
    }
}
