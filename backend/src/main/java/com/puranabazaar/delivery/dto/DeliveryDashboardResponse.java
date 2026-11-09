package com.puranabazaar.delivery.dto;

import com.puranabazaar.order.dto.OrderResponse;

import java.math.BigDecimal;
import java.util.List;

public record DeliveryDashboardResponse(
        String partnerName,
        long availableOrders,
        long activeDeliveries,
        long completedDeliveries,
        BigDecimal totalDeliveryFees,
        List<OrderResponse> activeOrders
) {
}
