package com.puranabazaar.cart;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface CartRepository extends JpaRepository<Cart, Long> {

    @Query("""
            select distinct c from Cart c
            left join fetch c.items i
            left join fetch i.product
            left join fetch i.shopInventory si
            left join fetch si.product
            left join fetch si.shop
            left join fetch c.selectedShop
            where c.customer.id = :customerId
            """)
    Optional<Cart> findByCustomerIdWithItems(@Param("customerId") Long customerId);

    Optional<Cart> findByCustomerId(Long customerId);
}
