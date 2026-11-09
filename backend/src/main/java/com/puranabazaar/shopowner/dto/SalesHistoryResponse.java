package com.puranabazaar.shopowner.dto;

import com.puranabazaar.order.dto.OrderResponse;

import java.math.BigDecimal;
import java.util.List;

public record SalesHistoryResponse(
        Long shopId,
        String shopName,
        BigDecimal totalSales,
        long deliveredOrders,
        List<OrderResponse> orders
) {
}
