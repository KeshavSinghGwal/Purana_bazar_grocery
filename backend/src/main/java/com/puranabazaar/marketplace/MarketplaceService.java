package com.puranabazaar.marketplace;

import com.puranabazaar.catalog.CatalogService;
import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.common.PageResponse;
import com.puranabazaar.marketplace.dto.FindShopRequest;
import com.puranabazaar.marketplace.dto.HomeResponse;
import com.puranabazaar.marketplace.dto.SearchResponse;
import com.puranabazaar.marketplace.dto.ShopQuoteResponse;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.ShopService;
import com.puranabazaar.shop.dto.ShopResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class MarketplaceService {

    private final CatalogService catalogService;
    private final ShopService shopService;
    private final ShopSelectionService selectionService;

    public MarketplaceService(CatalogService catalogService, ShopService shopService,
                              ShopSelectionService selectionService) {
        this.catalogService = catalogService;
        this.shopService = shopService;
        this.selectionService = selectionService;
    }

    @Transactional(readOnly = true)
    public PageResponse<ProductResponse> products(String query, Long categoryId, int page, int size,
                                                  BigDecimal maxPrice, boolean availableOnly) {
        return catalogService.searchProducts(query, categoryId, page, size, maxPrice, availableOnly);
    }

    @Transactional(readOnly = true)
    public ProductResponse product(Long id) {
        return catalogService.getProduct(id);
    }

    @Transactional(readOnly = true)
    public SearchResponse search(String query, Double lat, Double lng) {
        String term = query == null ? "" : query.trim();
        if (term.isBlank()) {
            return new SearchResponse(term, List.of(), List.of(),
                    shopService.listApproved(null, null, lat, lng, false, true));
        }
        var products = catalogService.searchProducts(term, null, 0, 20, null, false).content();
        var categories = catalogService.listCategories(false).stream()
                .filter(category -> category.name().toLowerCase().contains(term.toLowerCase()))
                .toList();
        var shops = shopService.listApproved(term, null, lat, lng, false, true);
        return new SearchResponse(term, products, categories, shops);
    }

    @Transactional(readOnly = true)
    public HomeResponse home(Double lat, Double lng) {
        List<CategoryResponse> categories = catalogService.listCategories(false);
        List<ProductResponse> featured = catalogService.searchProducts(null, null, 0, 12, null, true).content();
        List<ShopResponse> shops = lat != null && lng != null
                ? shopService.nearby(lat, lng, 8)
                : shopService.listApproved(null, null, null, null, false, true).stream().limit(8).toList();
        int totalShops = shopService.listApproved(null, null, null, null, false, true).size();
        return new HomeResponse(categories, featured, shops, totalShops, (int) catalogService.availability().size());
    }

    public ShopQuoteResponse findShop(FindShopRequest request) {
        return selectionService.findShopForProductChoice(CurrentUser.require(), request);
    }

    public ShopQuoteResponse validateCheckout(FindShopRequest request) {
        return selectionService.validateCheckout(CurrentUser.require(), request);
    }
}
