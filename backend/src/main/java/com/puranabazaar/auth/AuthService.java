package com.puranabazaar.auth;

import com.puranabazaar.auth.dto.*;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.security.JwtService;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopRepository;
import com.puranabazaar.user.Role;
import com.puranabazaar.user.User;
import com.puranabazaar.user.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.Optional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final ShopRepository shopRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository userRepository, ShopRepository shopRepository,
                       PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.shopRepository = shopRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthResponse registerCustomer(RegisterRequest request) {
        User user = createUser(request, Role.CUSTOMER);
        String token = jwtService.generateToken(user);
        return AuthResponse.of(token, jwtService.getExpirationMinutes(), toUser(user));
    }

    @Transactional
    public AuthResponse registerShopOwner(ShopOwnerRegisterRequest request) {
        User owner = createUser(new RegisterRequest(request.name(), request.email(), request.phone(), request.password()),
                Role.SHOP_OWNER);

        Shop shop = new Shop();
        shop.setOwner(owner);
        shop.setName(request.shopName().trim());
        shop.setDescription(request.description());
        shop.setAddress(request.address().trim());
        shop.setLatitude(request.latitude());
        shop.setLongitude(request.longitude());
        shop.setOpeningTime(request.openingTime());
        shop.setClosingTime(request.closingTime());
        shop.setDeliveryRadius(request.deliveryRadius());
        shop.setShopCategory(request.shopCategory());
        shop.setImageUrl(request.imageUrl());
        shop.setPhone(request.shopPhone() != null ? request.shopPhone() : request.phone());
        shop.setApprovalStatus(com.puranabazaar.shop.ShopApprovalStatus.PENDING_APPROVAL);
        shop = shopRepository.save(shop);

        String token = jwtService.generateToken(owner);
        return new AuthResponse(token, "Bearer", jwtService.getExpirationMinutes(),
                toUser(owner), shop.getId(), shop.getApprovalStatus().name());
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmailIgnoreCase(request.email().trim())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS",
                        "Incorrect email or password."));
        if (!user.isActive()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_DISABLED",
                    "This account has been suspended. Please contact support.");
        }
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Incorrect email or password.");
        }
        String token = jwtService.generateToken(user);
        Long shopId = null;
        String shopStatus = null;
        if (user.getRole() == Role.SHOP_OWNER) {
            Optional<Shop> shop = shopRepository.findFirstByOwnerId(user.getId());
            if (shop.isPresent()) {
                shopId = shop.get().getId();
                shopStatus = shop.get().getApprovalStatus().name();
            }
        }
        return new AuthResponse(token, "Bearer", jwtService.getExpirationMinutes(), toUser(user), shopId, shopStatus);
    }

    @Transactional(readOnly = true)
    public AccountResponse me() {
        User user = CurrentUser.require();
        Long shopId = null;
        String shopStatus = null;
        if (user.getRole() == Role.SHOP_OWNER) {
            Optional<Shop> shop = shopRepository.findFirstByOwnerId(user.getId());
            if (shop.isPresent()) {
                shopId = shop.get().getId();
                shopStatus = shop.get().getApprovalStatus().name();
            }
        }
        return new AccountResponse(toUser(user), shopId, shopStatus);
    }

    @Transactional(readOnly = true)
    public UserResponse updateProfile(String name, String phone) {
        User user = CurrentUser.require();
        if (name != null && !name.isBlank()) {
            user.setName(name.trim());
        }
        if (phone != null) {
            user.setPhone(phone.trim());
        }
        userRepository.save(user);
        return toUser(user);
    }

    public UserResponse toUser(User user) {
        return new UserResponse(user.getId(), user.getName(), user.getEmail(), user.getPhone(),
                user.getRole().name(), user.isActive(), user.getCreatedAt());
    }

    private User createUser(RegisterRequest request, Role role) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw ApiException.conflict("EMAIL_IN_USE", "An account with this email already exists.");
        }
        User user = new User();
        user.setName(request.name().trim());
        user.setEmail(email);
        user.setPhone(request.phone());
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setRole(role);
        user.setActive(true);
        return userRepository.save(user);
    }
}
