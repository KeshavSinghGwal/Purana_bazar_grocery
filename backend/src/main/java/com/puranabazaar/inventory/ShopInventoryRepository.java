package com.puranabazaar.inventory;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ShopInventoryRepository extends JpaRepository<ShopInventory, Long> {

    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            where i.shop.id = :shopId and i.active = true and p.active = true
            order by p.name asc
            """)
    List<ShopInventory> findActiveByShop(@Param("shopId") Long shopId);

    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            join fetch i.shop s
            where i.shop.id = :shopId
            order by p.name asc
            """)
    List<ShopInventory> findAllByShop(@Param("shopId") Long shopId);

    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            where i.shop.id = :shopId and i.product.id = :productId
            """)
    Optional<ShopInventory> findByShopAndProduct(@Param("shopId") Long shopId, @Param("productId") Long productId);

    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            where i.product.id in :productIds and i.active = true and i.availableQuantity > 0
              and i.shop.approvalStatus = com.puranabazaar.shop.ShopApprovalStatus.APPROVED
              and i.shop.operationalStatus = com.puranabazaar.shop.ShopOperationalStatus.ACTIVE
            """)
    List<ShopInventory> findAvailableForProducts(@Param("productIds") Collection<Long> productIds);

    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            where i.shop.id = :shopId and i.product.id in :productIds and i.active = true
            """)
    List<ShopInventory> findForShopAndProducts(@Param("shopId") Long shopId,
                                               @Param("productIds") Collection<Long> productIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select i from ShopInventory i
            join fetch i.product p
            where i.id in :ids
            order by i.id asc
            """)
    List<ShopInventory> lockAllById(@Param("ids") Collection<Long> ids);

    @Query("""
            select min(i.price) from ShopInventory i
            where i.product.id = :productId and i.active = true and i.availableQuantity > 0
              and i.shop.approvalStatus = com.puranabazaar.shop.ShopApprovalStatus.APPROVED
              and i.shop.operationalStatus = com.puranabazaar.shop.ShopOperationalStatus.ACTIVE
            """)
    BigDecimal findBestPrice(@Param("productId") Long productId);

    @Query("""
            select i.product.id, min(i.price), sum(i.availableQuantity), count(i)
            from ShopInventory i
            where i.active = true and i.availableQuantity > 0 and i.product.active = true
              and i.shop.approvalStatus = com.puranabazaar.shop.ShopApprovalStatus.APPROVED
              and i.shop.operationalStatus = com.puranabazaar.shop.ShopOperationalStatus.ACTIVE
            group by i.product.id
            """)
    List<Object[]> aggregateAvailability();

    @Query("""
            select count(i) from ShopInventory i
            where i.shop.id = :shopId and i.active = true and i.availableQuantity = 0
            """)
    long countOutOfStock(@Param("shopId") Long shopId);

    long countByShopIdAndActiveTrue(Long shopId);
}
