package com.puranabazaar.user;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmailIgnoreCase(String email);
    boolean existsByEmailIgnoreCase(String email);
    List<User> findAllByRoleOrderByCreatedAtDesc(Role role);
    long countByRole(Role role);
    long countByRoleAndActiveTrue(Role role);
}
