package com.puranabazaar.catalog;

import com.puranabazaar.catalog.dto.ProductResponse;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Small convenience adapter so services can map a product with the marketplace
 * availability snapshot without duplicating null handling.
 */
@Component
public class ProductPresenter {

    public ProductResponse present(Product product, Map<Long, CatalogService.Availability> availability) {
        CatalogService.Availability stats = availability.get(product.getId());
        BigDecimal bestPrice = stats != null ? stats.bestPrice() : null;
        int shops = stats != null ? stats.availableShops() : 0;
        int stock = stats != null ? stats.totalStock() : 0;
        return CatalogMapper.toProduct(product, bestPrice, shops, stock);
    }
}
