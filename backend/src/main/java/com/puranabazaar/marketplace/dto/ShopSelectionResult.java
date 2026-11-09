package com.puranabazaar.marketplace.dto;

public record ShopSelectionResult(
        Long shopId,
        double distanceKm,
        ShopQuoteResponse quote
) {
}
