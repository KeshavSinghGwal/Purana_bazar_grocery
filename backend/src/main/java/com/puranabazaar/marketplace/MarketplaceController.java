package com.puranabazaar.marketplace;

import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.common.PageResponse;
import com.puranabazaar.marketplace.dto.FindShopRequest;
import com.puranabazaar.marketplace.dto.HomeResponse;
import com.puranabazaar.marketplace.dto.SearchResponse;
import com.puranabazaar.marketplace.dto.ShopQuoteResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/api/marketplace")
public class MarketplaceController {

    private final MarketplaceService marketplaceService;

    public MarketplaceController(MarketplaceService marketplaceService) {
        this.marketplaceService = marketplaceService;
    }

    @GetMapping("/products")
    public PageResponse<ProductResponse> products(@RequestParam(required = false) String q,
                                                  @RequestParam(required = false) Long categoryId,
                                                  @RequestParam(defaultValue = "0") int page,
                                                  @RequestParam(defaultValue = "20") int size,
                                                  @RequestParam(required = false) BigDecimal maxPrice,
                                                  @RequestParam(defaultValue = "false") boolean availableOnly) {
        return marketplaceService.products(q, categoryId, page, size, maxPrice, availableOnly);
    }

    @GetMapping("/products/{id}")
    public ProductResponse product(@PathVariable Long id) {
        return marketplaceService.product(id);
    }

    @GetMapping("/search")
    public SearchResponse search(@RequestParam(required = false) String q,
                                 @RequestParam(required = false) Double lat,
                                 @RequestParam(required = false) Double lng) {
        return marketplaceService.search(q, lat, lng);
    }

    @GetMapping("/home")
    public HomeResponse home(@RequestParam(required = false) Double lat,
                             @RequestParam(required = false) Double lng) {
        return marketplaceService.home(lat, lng);
    }

    @PostMapping("/find-shop")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ShopQuoteResponse findShop(@Valid @RequestBody FindShopRequest request) {
        return marketplaceService.findShop(request);
    }

    @PostMapping("/checkout/validate")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ShopQuoteResponse validateCheckout(@Valid @RequestBody FindShopRequest request) {
        return marketplaceService.validateCheckout(request);
    }
}
