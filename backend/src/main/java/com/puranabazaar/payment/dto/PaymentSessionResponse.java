package com.puranabazaar.payment.dto;

import java.math.BigDecimal;

public record PaymentSessionResponse(
        Long orderId,
        String orderNumber,
        String gateway,
        String razorpayOrderId,
        String razorpayKeyId,
        long amountPaise,
        BigDecimal amount,
        String currency,
        boolean mock,
        String customerName,
        String customerEmail,
        String customerPhone,
        String description,
        String themeColor
) {
}
