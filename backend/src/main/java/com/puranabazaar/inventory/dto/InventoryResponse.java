package com.puranabazaar.inventory.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.Instant;

public record InventoryResponse(
        Long id,
        Long productId,
        String productName,
        String brand,
        String unit,
        String imageUrl,
        Long categoryId,
        String categoryName,
        BigDecimal price,
        int availableQuantity,
        boolean active,
        Instant updatedAt
) {
}
