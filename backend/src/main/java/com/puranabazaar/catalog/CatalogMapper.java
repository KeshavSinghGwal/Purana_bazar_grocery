package com.puranabazaar.catalog;

import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;

import java.math.BigDecimal;

public final class CatalogMapper {

    private CatalogMapper() {
    }

    public static CategoryResponse toCategory(Category category) {
        return new CategoryResponse(category.getId(), category.getName(), category.getDescription(),
                category.getImageUrl(), category.isActive(), category.getDisplayOrder());
    }

    public static ProductResponse toProduct(Product product, BigDecimal bestPrice,
                                            int availableShops, int totalStock) {
        return new ProductResponse(
                product.getId(),
                product.getName(),
                product.getDescription(),
                product.getBrand(),
                product.getCategory().getId(),
                product.getCategory().getName(),
                product.getImageUrl(),
                product.getUnit(),
                product.isActive(),
                bestPrice,
                availableShops,
                totalStock
        );
    }

    public static ProductResponse toProduct(Product product, java.util.Map<Long, CatalogService.Availability> availability) {
        CatalogService.Availability stats = availability.get(product.getId());
        return toProduct(product,
                stats != null ? stats.bestPrice() : null,
                stats != null ? stats.availableShops() : 0,
                stats != null ? stats.totalStock() : 0);
    }
}
