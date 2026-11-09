package com.puranabazaar.wishlist;

import com.puranabazaar.wishlist.dto.WishlistItemResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/wishlist")
@PreAuthorize("hasRole('CUSTOMER')")
public class WishlistController {

    private final WishlistService wishlistService;

    public WishlistController(WishlistService wishlistService) {
        this.wishlistService = wishlistService;
    }

    @GetMapping
    public List<WishlistItemResponse> list() {
        return wishlistService.list();
    }

    @PostMapping("/{productId}")
    public ResponseEntity<WishlistItemResponse> add(@PathVariable Long productId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(wishlistService.add(productId));
    }

    @DeleteMapping("/{productId}")
    public ResponseEntity<Void> remove(@PathVariable Long productId) {
        wishlistService.remove(productId);
        return ResponseEntity.noContent().build();
    }
}
