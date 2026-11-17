package com.puranabazaar.payment.dto;

import java.math.BigDecimal;

public record PaymentStatusResponse(
        Long orderId,
        String orderNumber,
        String paymentMethod,
        String paymentStatus,
        String orderStatus,
        String gateway,
        String gatewayOrderId,
        String gatewayPaymentId,
        String reference,
        BigDecimal amount,
        boolean retryable
) {
}
