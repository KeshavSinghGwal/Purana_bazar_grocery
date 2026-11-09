package com.puranabazaar.wishlist.dto;

import com.puranabazaar.catalog.dto.ProductResponse;

import java.time.Instant;

public record WishlistItemResponse(
        Long id,
        ProductResponse product,
        Instant createdAt
) {
}
