package com.puranabazaar.catalog;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProductRepository extends JpaRepository<Product, Long> {

    Optional<Product> findByIdAndActiveTrue(Long id);

    boolean existsByNameIgnoreCaseAndBrandIgnoreCase(String name, String brand);

    List<Product> findAllByActiveTrueOrderByNameAsc();

    @Query("""
            select p from Product p
            where p.active = true
              and (:query = ''
                   or lower(p.name) like lower(concat('%', :query, '%'))
                   or lower(coalesce(p.brand, '')) like lower(concat('%', :query, '%')))
              and (:categoryId is null or p.category.id = :categoryId)
            """)
    Page<Product> search(@Param("query") String query, @Param("categoryId") Long categoryId, Pageable pageable);

    @Query("""
            select p from Product p
            where p.active = true and p.category.id = :categoryId
            order by p.name asc
            """)
    List<Product> findActiveByCategory(@Param("categoryId") Long categoryId);

    @Query("""
            select p from Product p
            where (:query = ''
                   or lower(p.name) like lower(concat('%', :query, '%')))
              and (:categoryId is null or p.category.id = :categoryId)
            order by p.name asc
            """)
    Page<Product> adminSearch(@Param("query") String query, @Param("categoryId") Long categoryId, Pageable pageable);

    long countByActiveTrue();
}
