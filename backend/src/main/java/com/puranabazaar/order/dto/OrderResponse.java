package com.puranabazaar.order.dto;

import com.puranabazaar.shop.dto.ShopResponse;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record OrderResponse(
        Long id,
        String orderNumber,
        String shoppingMode,
        String orderStatus,
        String paymentStatus,
        String paymentMethod,
        ShopResponse shop,
        String customerName,
        String customerPhone,
        String deliveryPartnerName,
        String deliveryPartnerPhone,
        String deliveryAddress,
        double deliveryLatitude,
        double deliveryLongitude,
        BigDecimal subtotal,
        BigDecimal deliveryCharge,
        BigDecimal totalAmount,
        List<OrderItemResponse> items,
        String customerNote,
        String cancellationReason,
        boolean canCancel,
        Instant createdAt,
        Instant updatedAt,
        String paymentReference,
        String paymentGateway,
        boolean canRetryPayment
) {
}
