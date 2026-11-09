package com.puranabazaar.shop;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ShopRepository extends JpaRepository<Shop, Long> {

    Optional<Shop> findFirstByOwnerId(Long ownerId);

    boolean existsByOwnerId(Long ownerId);

    List<Shop> findAllByApprovalStatusOrderByCreatedAtDesc(ShopApprovalStatus status);

    List<Shop> findAllByOrderByCreatedAtDesc();

    long countByApprovalStatus(ShopApprovalStatus status);

    @Query("""
            select s from Shop s
            where s.approvalStatus = com.puranabazaar.shop.ShopApprovalStatus.APPROVED
              and s.operationalStatus = com.puranabazaar.shop.ShopOperationalStatus.ACTIVE
            """)
    List<Shop> findApprovedAndActive();

    @Query("""
            select s from Shop s
            where s.approvalStatus = com.puranabazaar.shop.ShopApprovalStatus.APPROVED
              and s.operationalStatus = com.puranabazaar.shop.ShopOperationalStatus.ACTIVE
              and (lower(s.name) like lower(concat('%', :query, '%'))
                   or lower(s.address) like lower(concat('%', :query, '%')))
            """)
    List<Shop> searchApproved(@Param("query") String query);
}
