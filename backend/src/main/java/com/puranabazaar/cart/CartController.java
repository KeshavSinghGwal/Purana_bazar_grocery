package com.puranabazaar.cart;

import com.puranabazaar.cart.dto.AddCartItemRequest;
import com.puranabazaar.cart.dto.CartResponse;
import com.puranabazaar.cart.dto.UpdateCartItemRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/cart")
@PreAuthorize("hasRole('CUSTOMER')")
public class CartController {

    private final CartService cartService;

    public CartController(CartService cartService) {
        this.cartService = cartService;
    }

    @GetMapping
    public CartResponse get() {
        return cartService.getCart();
    }

    @PostMapping("/items")
    public ResponseEntity<CartResponse> add(@Valid @RequestBody AddCartItemRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(cartService.addItem(request));
    }

    @PutMapping("/items/{id}")
    public CartResponse update(@PathVariable Long id, @Valid @RequestBody UpdateCartItemRequest request) {
        return cartService.updateQuantity(id, request.quantity());
    }

    @DeleteMapping("/items/{id}")
    public CartResponse remove(@PathVariable Long id) {
        return cartService.removeItem(id);
    }

    @DeleteMapping
    public CartResponse clear() {
        return cartService.clear();
    }
}
