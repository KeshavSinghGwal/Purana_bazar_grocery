package com.puranabazaar.catalog.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record ProductResponse(
        Long id,
        String name,
        String description,
        String brand,
        Long categoryId,
        String categoryName,
        String imageUrl,
        String unit,
        boolean active,
        BigDecimal bestPrice,
        int availableShops,
        int totalStock
) {
}
