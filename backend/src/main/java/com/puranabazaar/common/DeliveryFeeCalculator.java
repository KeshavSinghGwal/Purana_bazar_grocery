package com.puranabazaar.common;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Component
public class DeliveryFeeCalculator {

    private final BigDecimal baseFee;
    private final BigDecimal freeAbove;

    public DeliveryFeeCalculator(@Value("${app.delivery.base-fee:19}") BigDecimal baseFee,
                                 @Value("${app.delivery.free-above:199}") BigDecimal freeAbove) {
        this.baseFee = baseFee;
        this.freeAbove = freeAbove;
    }

    /**
     * Flat local delivery fee. Because Purana Bazaar always dispatches from the nearest
     * eligible shop, the delivery distance (and therefore the courier cost) stays minimal.
     */
    public BigDecimal feeFor(BigDecimal subtotal) {
        if (subtotal == null || subtotal.compareTo(freeAbove) >= 0) {
            return BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        return baseFee.setScale(2, RoundingMode.HALF_UP);
    }

    public BigDecimal getBaseFee() {
        return baseFee;
    }
}
