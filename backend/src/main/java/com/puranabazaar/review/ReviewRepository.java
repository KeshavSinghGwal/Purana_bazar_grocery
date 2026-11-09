package com.puranabazaar.review;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    List<Review> findByShopIdOrderByCreatedAtDesc(Long shopId);
    Optional<Review> findByCustomerIdAndShopId(Long customerId, Long shopId);

    @Query("select avg(r.rating) from Review r where r.shop.id = :shopId")
    Double averageRating(@Param("shopId") Long shopId);

    long countByShopId(Long shopId);
}
