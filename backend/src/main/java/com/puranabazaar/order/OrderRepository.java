package com.puranabazaar.order;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<ShopOrder, Long> {

    List<ShopOrder> findByCustomerIdOrderByCreatedAtDesc(Long customerId);

    Optional<ShopOrder> findByIdAndCustomerId(Long id, Long customerId);

    Optional<ShopOrder> findByCustomerIdAndIdempotencyKey(Long customerId, String idempotencyKey);

    List<ShopOrder> findByShopIdOrderByCreatedAtDesc(Long shopId);

    List<ShopOrder> findByShopIdAndOrderStatusOrderByCreatedAtDesc(Long shopId, OrderStatus status);

    List<ShopOrder> findByOrderStatusAndDeliveryPartnerIsNullOrderByCreatedAtAsc(OrderStatus status);

    List<ShopOrder> findByDeliveryPartnerIdOrderByCreatedAtDesc(Long deliveryPartnerId);

    List<ShopOrder> findByDeliveryPartnerIdAndOrderStatusOrderByCreatedAtDesc(Long deliveryPartnerId,
                                                                             OrderStatus status);

    Optional<ShopOrder> findByIdAndDeliveryPartnerId(Long id, Long deliveryPartnerId);

    List<ShopOrder> findByOrderStatusAndCreatedAtBefore(OrderStatus status, java.time.Instant cutoff);

    long countByDeliveryPartnerIdAndOrderStatus(Long deliveryPartnerId, OrderStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select o from ShopOrder o where o.id = :id")
    Optional<ShopOrder> findByIdForUpdate(@Param("id") Long id);

    @Query("""
            select o from ShopOrder o
            where (:status is null or o.orderStatus = :status)
              and (:shopId is null or o.shop.id = :shopId)
            order by o.createdAt desc
            """)
    List<ShopOrder> adminSearch(@Param("status") OrderStatus status, @Param("shopId") Long shopId);

    long countByOrderStatus(OrderStatus status);

    long countByShopIdAndOrderStatus(Long shopId, OrderStatus status);

    long countByCustomerId(Long customerId);

    boolean existsByCustomerIdAndShopIdAndOrderStatus(Long customerId, Long shopId, OrderStatus status);

    long countByShopId(Long shopId);

    @Query("select coalesce(sum(o.totalAmount), 0) from ShopOrder o where o.orderStatus = com.puranabazaar.order.OrderStatus.DELIVERED")
    BigDecimal totalDeliveredSales();

    @Query("""
            select coalesce(sum(o.deliveryCharge), 0) from ShopOrder o
            where o.deliveryPartner.id = :partnerId
              and o.orderStatus = com.puranabazaar.order.OrderStatus.DELIVERED
            """)
    BigDecimal totalDeliveryFeesForPartner(@Param("partnerId") Long partnerId);

    @Query("""
            select coalesce(sum(o.totalAmount), 0) from ShopOrder o
            where o.shop.id = :shopId and o.orderStatus = com.puranabazaar.order.OrderStatus.DELIVERED
            """)
    BigDecimal totalDeliveredSalesForShop(@Param("shopId") Long shopId);
}
