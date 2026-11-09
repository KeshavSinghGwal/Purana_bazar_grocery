package com.puranabazaar.marketplace.dto;

import com.puranabazaar.shop.dto.ShopResponse;

import java.math.BigDecimal;
import java.util.List;

public record ShopQuoteResponse(
        boolean found,
        String message,
        ShopResponse selectedShop,
        Double distanceKm,
        List<QuoteLine> items,
        BigDecimal subtotal,
        BigDecimal deliveryCharge,
        BigDecimal totalAmount,
        List<UnavailableProduct> unavailableProducts,
        List<ShopCandidate> consideredShops
) {
    public record QuoteLine(
            Long productId,
            String name,
            String brand,
            String unit,
            String imageUrl,
            int requestedQuantity,
            int availableQuantity,
            BigDecimal unitPrice,
            BigDecimal lineTotal
    ) {
    }

    public record UnavailableProduct(
            Long productId,
            String name,
            int requestedQuantity,
            int maxAvailable
    ) {
    }

    public record ShopCandidate(
            Long id,
            String name,
            double distanceKm,
            boolean eligible,
            String reason
    ) {
    }
}
