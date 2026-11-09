package com.puranabazaar.cart;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CartItemRepository extends JpaRepository<CartItem, Long> {
    Optional<CartItem> findByCartIdAndProductId(Long cartId, Long productId);
    Optional<CartItem> findByCartIdAndShopInventoryId(Long cartId, Long shopInventoryId);
    Optional<CartItem> findByIdAndCartId(Long id, Long cartId);
}
