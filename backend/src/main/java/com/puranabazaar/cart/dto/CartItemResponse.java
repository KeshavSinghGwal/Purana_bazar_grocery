package com.puranabazaar.cart.dto;

import java.math.BigDecimal;

public record CartItemResponse(
        Long id,
        Long productId,
        Long shopInventoryId,
        Long shopId,
        String name,
        String brand,
        String unit,
        String imageUrl,
        int quantity,
        BigDecimal unitPrice,
        BigDecimal lineTotal,
        int availableQuantity,
        boolean available,
        Long categoryId,
        String categoryName
) {
}
