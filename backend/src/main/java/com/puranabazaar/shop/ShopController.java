package com.puranabazaar.shop;

import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.inventory.dto.InventoryResponse;
import com.puranabazaar.review.ReviewService;
import com.puranabazaar.review.dto.ReviewRequest;
import com.puranabazaar.review.dto.ReviewResponse;
import com.puranabazaar.shop.dto.ShopResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/shops")
public class ShopController {

    private final ShopService shopService;
    private final ReviewService reviewService;

    public ShopController(ShopService shopService, ReviewService reviewService) {
        this.shopService = shopService;
        this.reviewService = reviewService;
    }

    @GetMapping
    public List<ShopResponse> list(@RequestParam(required = false) String q,
                                   @RequestParam(required = false) String category,
                                   @RequestParam(required = false) Double lat,
                                   @RequestParam(required = false) Double lng,
                                   @RequestParam(defaultValue = "false") boolean onlyOpen,
                                   @RequestParam(defaultValue = "distance") String sort) {
        return shopService.listApproved(q, category, lat, lng, onlyOpen, "distance".equalsIgnoreCase(sort));
    }

    @GetMapping("/nearby")
    public List<ShopResponse> nearby(@RequestParam double lat, @RequestParam double lng,
                                     @RequestParam(defaultValue = "20") int limit) {
        return shopService.nearby(lat, lng, limit);
    }

    @GetMapping("/{id}")
    public ShopResponse get(@PathVariable Long id,
                            @RequestParam(required = false) Double lat,
                            @RequestParam(required = false) Double lng) {
        return shopService.getApproved(id, lat, lng);
    }

    @GetMapping("/{id}/products")
    public List<ProductResponse> products(@PathVariable Long id,
                                          @RequestParam(required = false) Double lat,
                                          @RequestParam(required = false) Double lng) {
        return shopService.shopProducts(id, lat, lng);
    }

    @GetMapping("/{id}/inventory")
    public List<InventoryResponse> inventory(@PathVariable Long id) {
        return shopService.shopInventory(id);
    }

    @GetMapping("/{id}/categories")
    public List<CategoryResponse> categories(@PathVariable Long id) {
        return shopService.shopCategories(id);
    }

    @GetMapping("/{id}/reviews")
    public List<ReviewResponse> reviews(@PathVariable Long id) {
        return reviewService.list(id);
    }

    @PostMapping("/{id}/reviews")
    @PreAuthorize("hasRole('CUSTOMER')")
    public ResponseEntity<ReviewResponse> review(@PathVariable Long id,
                                                 @Valid @RequestBody ReviewRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(reviewService.submit(id, request));
    }
}
