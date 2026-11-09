package com.puranabazaar.admin.dto;

import java.math.BigDecimal;

public record AdminDashboardResponse(
        long totalShops,
        long approvedShops,
        long pendingShops,
        long suspendedShops,
        long totalCustomers,
        long activeCustomers,
        long totalProducts,
        long totalCategories,
        long totalOrders,
        long pendingOrders,
        long completedOrders,
        long cancelledOrders,
        BigDecimal totalSales
) {
}
