package com.puranabazaar.order.dto;

import java.math.BigDecimal;

public record OrderItemResponse(
        Long id,
        Long productId,
        String productName,
        String brand,
        String unit,
        String imageUrl,
        BigDecimal price,
        int quantity,
        BigDecimal totalPrice
) {
}
