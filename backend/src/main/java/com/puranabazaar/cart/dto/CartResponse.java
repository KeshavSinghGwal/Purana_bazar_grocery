package com.puranabazaar.cart.dto;

import com.puranabazaar.shop.dto.ShopResponse;

import java.math.BigDecimal;
import java.util.List;

public record CartResponse(
        Long id,
        String shoppingMode,
        ShopResponse selectedShop,
        List<CartItemResponse> items,
        int itemCount,
        BigDecimal subtotal,
        BigDecimal estimatedDeliveryCharge,
        BigDecimal estimatedTotal,
        boolean hasAvailabilityIssues,
        String notice
) {
}
