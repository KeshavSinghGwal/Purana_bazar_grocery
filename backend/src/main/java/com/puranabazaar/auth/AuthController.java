package com.puranabazaar.auth;

import com.puranabazaar.auth.dto.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/api/auth/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.registerCustomer(request));
    }

    @PostMapping("/api/auth/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/api/auth/logout")
    public Map<String, String> logout() {
        // Stateless JWT: the client discards its token. Endpoint exists for API symmetry.
        return Map.of("message", "Signed out successfully.");
    }

    @GetMapping("/api/auth/me")
    public AccountResponse me() {
        return authService.me();
    }

    @PostMapping("/api/shop-owner/register")
    public ResponseEntity<AuthResponse> registerShopOwner(@Valid @RequestBody ShopOwnerRegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.registerShopOwner(request));
    }
}
