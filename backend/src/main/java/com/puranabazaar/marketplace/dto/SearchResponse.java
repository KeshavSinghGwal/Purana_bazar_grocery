package com.puranabazaar.marketplace.dto;

import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.shop.dto.ShopResponse;

import java.util.List;

public record SearchResponse(
        String query,
        List<ProductResponse> products,
        List<CategoryResponse> categories,
        List<ShopResponse> shops
) {
}
