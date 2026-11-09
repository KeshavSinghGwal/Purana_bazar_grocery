package com.puranabazaar.shopowner.dto;

import com.puranabazaar.order.dto.OrderResponse;

import java.math.BigDecimal;
import java.util.List;

public record OwnerDashboardResponse(
        Long shopId,
        String shopName,
        String approvalStatus,
        String operationalStatus,
        String address,
        long totalProducts,
        long outOfStockProducts,
        long totalOrders,
        long pendingOrders,
        long deliveredOrders,
        BigDecimal totalSales,
        List<OrderResponse> recentOrders
) {
}
