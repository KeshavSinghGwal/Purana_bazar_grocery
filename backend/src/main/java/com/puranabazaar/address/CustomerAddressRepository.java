package com.puranabazaar.address;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CustomerAddressRepository extends JpaRepository<CustomerAddress, Long> {
    List<CustomerAddress> findByCustomerIdOrderByDefaultAddressDescCreatedAtDesc(Long customerId);
    Optional<CustomerAddress> findByIdAndCustomerId(Long id, Long customerId);
    Optional<CustomerAddress> findFirstByCustomerIdAndDefaultAddressTrue(Long customerId);
    long countByCustomerId(Long customerId);

    @Modifying
    @Query("update CustomerAddress a set a.defaultAddress = false where a.customer.id = :customerId")
    void clearDefaultForCustomer(@Param("customerId") Long customerId);
}
