package com.puranabazaar.admin;

import com.puranabazaar.admin.dto.AdminCustomerResponse;
import com.puranabazaar.admin.dto.AdminDashboardResponse;
import com.puranabazaar.catalog.CategoryRepository;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.notification.NotificationService;
import com.puranabazaar.order.OrderRepository;
import com.puranabazaar.order.OrderService;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.ShopMapper;
import com.puranabazaar.shop.ShopOperationalStatus;
import com.puranabazaar.shop.ShopRepository;
import com.puranabazaar.shop.dto.ShopResponse;
import com.puranabazaar.user.Role;
import com.puranabazaar.user.User;
import com.puranabazaar.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;

@Service
public class AdminService {

    private final ShopRepository shopRepository;
    private final ShopMapper shopMapper;
    private final UserRepository userRepository;
    private final OrderRepository orderRepository;
    private final OrderService orderService;
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final NotificationService notificationService;

    public AdminService(ShopRepository shopRepository, ShopMapper shopMapper, UserRepository userRepository,
                        OrderRepository orderRepository, OrderService orderService,
                        ProductRepository productRepository, CategoryRepository categoryRepository,
                        NotificationService notificationService) {
        this.shopRepository = shopRepository;
        this.shopMapper = shopMapper;
        this.userRepository = userRepository;
        this.orderRepository = orderRepository;
        this.orderService = orderService;
        this.productRepository = productRepository;
        this.categoryRepository = categoryRepository;
        this.notificationService = notificationService;
    }

    @Transactional(readOnly = true)
    public AdminDashboardResponse dashboard() {
        long cancelled = orderRepository.countByOrderStatus(OrderStatus.CANCELLED)
                + orderRepository.countByOrderStatus(OrderStatus.REJECTED);
        return new AdminDashboardResponse(
                shopRepository.count(),
                shopRepository.countByApprovalStatus(ShopApprovalStatus.APPROVED),
                shopRepository.countByApprovalStatus(ShopApprovalStatus.PENDING_APPROVAL),
                shopRepository.countByApprovalStatus(ShopApprovalStatus.SUSPENDED),
                userRepository.countByRole(Role.CUSTOMER),
                userRepository.countByRoleAndActiveTrue(Role.CUSTOMER),
                productRepository.countByActiveTrue(),
                categoryRepository.countByActiveTrue(),
                orderRepository.count(),
                orderRepository.countByOrderStatus(OrderStatus.PENDING),
                orderRepository.countByOrderStatus(OrderStatus.DELIVERED),
                cancelled,
                orderRepository.totalDeliveredSales().setScale(2, RoundingMode.HALF_UP)
        );
    }

    @Transactional(readOnly = true)
    public List<ShopResponse> shops(ShopApprovalStatus status) {
        List<Shop> shops = status == null
                ? shopRepository.findAllByOrderByCreatedAtDesc()
                : shopRepository.findAllByApprovalStatusOrderByCreatedAtDesc(status);
        return shops.stream().map(shop -> shopMapper.toResponse(shop, null, null)).toList();
    }

    @Transactional(readOnly = true)
    public ShopResponse shop(Long id) {
        Shop shop = shopRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND", "Shop not found."));
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse approve(Long id) {
        Shop shop = requireShop(id);
        shop.setApprovalStatus(ShopApprovalStatus.APPROVED);
        shop.setApprovedAt(Instant.now());
        shop.setRejectionReason(null);
        shop.setOperationalStatus(ShopOperationalStatus.ACTIVE);
        shopRepository.save(shop);
        notificationService.notifyUser(shop.getOwner(), "Shop approved 🎉",
                shop.getName() + " is now live on Purana Bazaar. Customers can find and order from you.",
                "SHOP", null, null);
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse reject(Long id, String reason) {
        Shop shop = requireShop(id);
        shop.setApprovalStatus(ShopApprovalStatus.REJECTED);
        shop.setRejectionReason(reason);
        shopRepository.save(shop);
        notificationService.notifyUser(shop.getOwner(), "Shop registration needs attention",
                "Your shop " + shop.getName() + " could not be approved."
                        + (reason == null || reason.isBlank() ? "" : " Reason: " + reason),
                "SHOP", null, null);
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse suspend(Long id, String reason) {
        Shop shop = requireShop(id);
        shop.setApprovalStatus(ShopApprovalStatus.SUSPENDED);
        shop.setRejectionReason(reason);
        shopRepository.save(shop);
        notificationService.notifyUser(shop.getOwner(), "Shop suspended",
                shop.getName() + " has been suspended and is hidden from customers."
                        + (reason == null || reason.isBlank() ? "" : " Reason: " + reason),
                "SHOP", null, null);
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse reactivate(Long id) {
        return approve(id);
    }

    @Transactional(readOnly = true)
    public List<AdminCustomerResponse> customers() {
        return userRepository.findAllByRoleOrderByCreatedAtDesc(Role.CUSTOMER).stream()
                .map(user -> new AdminCustomerResponse(user.getId(), user.getName(), user.getEmail(),
                        user.getPhone(), user.isActive(), user.getCreatedAt(),
                        orderRepository.countByCustomerId(user.getId())))
                .toList();
    }

    @Transactional
    public AdminCustomerResponse setCustomerActive(Long customerId, boolean active) {
        User user = userRepository.findById(customerId)
                .filter(u -> u.getRole() == Role.CUSTOMER)
                .orElseThrow(() -> ApiException.notFound("CUSTOMER_NOT_FOUND", "Customer not found."));
        user.setActive(active);
        userRepository.save(user);
        notificationService.notifyUser(user, active ? "Account reactivated" : "Account suspended",
                active
                        ? "Your Purana Bazaar account is active again. Welcome back!"
                        : "Your account has been suspended. Please contact support if you believe this is a mistake.",
                "ACCOUNT", null, null);
        return new AdminCustomerResponse(user.getId(), user.getName(), user.getEmail(), user.getPhone(),
                user.isActive(), user.getCreatedAt(), orderRepository.countByCustomerId(user.getId()));
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> orders(OrderStatus status, Long shopId) {
        return orderRepository.adminSearch(status, shopId).stream().map(orderService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse order(Long id) {
        return orderService.toResponse(orderRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found.")));
    }

    @Transactional
    public OrderResponse cancelOrder(Long id, String reason) {
        return orderService.cancelByAdmin(id, reason);
    }

    private Shop requireShop(Long id) {
        return shopRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND", "Shop not found."));
    }
}
