package com.puranabazaar.marketplace.dto;

import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.shop.dto.ShopResponse;

import java.util.List;

public record HomeResponse(
        List<CategoryResponse> categories,
        List<ProductResponse> featuredProducts,
        List<ShopResponse> nearbyShops,
        int totalShops,
        int totalProducts
) {
}
