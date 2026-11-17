package com.puranabazaar.order;

import com.puranabazaar.address.CustomerAddress;
import com.puranabazaar.address.CustomerAddressRepository;
import com.puranabazaar.cart.Cart;
import com.puranabazaar.cart.CartItem;
import com.puranabazaar.cart.CartRepository;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.common.DeliveryFeeCalculator;
import com.puranabazaar.common.GeoUtils;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.marketplace.ShopSelectionService;
import com.puranabazaar.marketplace.dto.ShopQuoteResponse;
import com.puranabazaar.notification.NotificationService;
import com.puranabazaar.order.dto.*;
import com.puranabazaar.payment.Payment;
import com.puranabazaar.payment.PaymentRepository;
import com.puranabazaar.payment.PaymentService;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.*;
import com.puranabazaar.user.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final CartRepository cartRepository;
    private final CustomerAddressRepository addressRepository;
    private final ShopRepository shopRepository;
    private final ShopInventoryRepository inventoryRepository;
    private final PaymentRepository paymentRepository;
    private final ShopSelectionService selectionService;
    private final DeliveryFeeCalculator feeCalculator;
    private final OrderMapper orderMapper;
    private final NotificationService notificationService;
    private final PaymentService paymentService;
    private final ZoneId zoneId;
    private final long pendingTimeoutMinutes;

    public OrderService(OrderRepository orderRepository, CartRepository cartRepository,
                        CustomerAddressRepository addressRepository, ShopRepository shopRepository,
                        ShopInventoryRepository inventoryRepository, PaymentRepository paymentRepository,
                        ShopSelectionService selectionService, DeliveryFeeCalculator feeCalculator,
                        OrderMapper orderMapper, NotificationService notificationService,
                        PaymentService paymentService,
                        @Value("${app.timezone:Asia/Kolkata}") String timezone,
                        @Value("${app.payment.pending-timeout-minutes:120}") long pendingTimeoutMinutes) {
        this.orderRepository = orderRepository;
        this.cartRepository = cartRepository;
        this.addressRepository = addressRepository;
        this.shopRepository = shopRepository;
        this.inventoryRepository = inventoryRepository;
        this.paymentRepository = paymentRepository;
        this.selectionService = selectionService;
        this.feeCalculator = feeCalculator;
        this.orderMapper = orderMapper;
        this.notificationService = notificationService;
        this.paymentService = paymentService;
        this.zoneId = ZoneId.of(timezone);
        this.pendingTimeoutMinutes = pendingTimeoutMinutes;
    }

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        User customer = CurrentUser.require();
        Optional<ShopOrder> replay = orderRepository.findByCustomerIdAndIdempotencyKey(
                customer.getId(), request.idempotencyKey());
        if (replay.isPresent()) {
            return toResponse(replay.get());
        }

        CustomerAddress address = addressRepository.findByIdAndCustomerId(request.addressId(), customer.getId())
                .orElseThrow(() -> ApiException.notFound("ADDRESS_NOT_FOUND", "Delivery address not found."));
        Cart cart = cartRepository.findByCustomerIdWithItems(customer.getId())
                .filter(c -> !c.getItems().isEmpty())
                .orElseThrow(() -> ApiException.badRequest("CART_EMPTY", "Your cart is empty."));

        Shop shop;
        Map<Long, Integer> quantities = new LinkedHashMap<>();
        List<ShopInventory> locked;
        if (cart.getShoppingMode() == com.puranabazaar.cart.ShoppingMode.PRODUCT_CHOICE) {
            ShopQuoteResponse quote = selectionService.quoteNearestShop(
                    new ShopSelectionService.Location(address.getLatitude(), address.getLongitude()),
                    selectionService.cartLines(cart));
            if (!quote.found() || quote.selectedShop() == null) {
                throw ApiException.conflict("NO_ELIGIBLE_SHOP", quote.message(), quote);
            }
            shop = shopRepository.findById(quote.selectedShop().id())
                    .orElseThrow(() -> ApiException.conflict("NO_ELIGIBLE_SHOP", quote.message()));
            collectQuantities(cart, quantities);
            List<Long> ids = inventoryRepository.findForShopAndProducts(shop.getId(), quantities.keySet())
                    .stream().map(ShopInventory::getId).toList();
            locked = inventoryRepository.lockAllById(ids);
        } else {
            if (cart.getSelectedShop() == null) {
                throw ApiException.conflict("SHOP_REQUIRED", "Select a shop before checkout.");
            }
            shop = shopRepository.findById(cart.getSelectedShop().getId())
                    .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND", "Shop not found."));
            collectQuantities(cart, quantities);
            List<Long> ids = new ArrayList<>();
            for (CartItem item : cart.getItems()) {
                if (item.getShopInventory() == null) {
                    throw ApiException.conflict("INVALID_CART", "Cart item is missing its shop listing.");
                }
                if (!item.getShopInventory().getShop().getId().equals(shop.getId())) {
                    throw ApiException.conflict("MIXED_SHOP_CART",
                            "A Shop Choice order can only contain products from one shop.");
                }
                ids.add(item.getShopInventory().getId());
            }
            locked = inventoryRepository.lockAllById(ids.stream().sorted().toList());
        }

        validateShopDelivery(shop, address.getLatitude(), address.getLongitude());
        Map<Long, ShopInventory> inventoryByProduct = new HashMap<>();
        for (ShopInventory inventory : locked) {
            inventoryByProduct.put(inventory.getProduct().getId(), inventory);
        }

        BigDecimal subtotal = BigDecimal.ZERO;
        for (Map.Entry<Long, Integer> entry : quantities.entrySet()) {
            ShopInventory inventory = inventoryByProduct.get(entry.getKey());
            if (inventory == null || !inventory.isActive()) {
                throw ApiException.conflict("ITEM_UNAVAILABLE",
                        "One of the products is no longer available at this shop. Please refresh your cart.");
            }
            if (inventory.getAvailableQuantity() < entry.getValue()) {
                throw ApiException.conflict("INSUFFICIENT_STOCK",
                        inventory.getProduct().getName() + " now has only "
                                + inventory.getAvailableQuantity() + " units available.");
            }
            subtotal = subtotal.add(inventory.getPrice().multiply(BigDecimal.valueOf(entry.getValue())));
        }
        subtotal = subtotal.setScale(2, RoundingMode.HALF_UP);
        BigDecimal delivery = feeCalculator.feeFor(subtotal);
        boolean online = request.paymentMethod() == PaymentMethod.ONLINE;

        ShopOrder order = new ShopOrder();
        order.setCustomer(customer);
        order.setShop(shop);
        order.setOrderNumber(newOrderNumber());
        order.setShoppingMode(cart.getShoppingMode());
        order.setIdempotencyKey(request.idempotencyKey());
        order.setDeliveryAddress(address.asText());
        order.setDeliveryCity(address.getCity());
        order.setDeliveryPostalCode(address.getPostalCode());
        order.setDeliveryLatitude(address.getLatitude());
        order.setDeliveryLongitude(address.getLongitude());
        order.setDeliveryPhone(customer.getPhone());
        order.setSubtotal(subtotal);
        order.setDeliveryCharge(delivery);
        order.setTotalAmount(subtotal.add(delivery));
        order.setPaymentMethod(request.paymentMethod());
        order.setPaymentStatus(PaymentStatus.PENDING);
        order.setOrderStatus(online ? OrderStatus.PAYMENT_PENDING : OrderStatus.PENDING);
        order.setCustomerNote(request.customerNote());

        for (Map.Entry<Long, Integer> entry : quantities.entrySet()) {
            ShopInventory inventory = inventoryByProduct.get(entry.getKey());
            OrderItem item = new OrderItem();
            item.setProduct(inventory.getProduct());
            item.setShopInventory(inventory);
            item.setProductNameSnapshot(inventory.getProduct().getName());
            item.setBrandSnapshot(inventory.getProduct().getBrand());
            item.setUnitSnapshot(inventory.getProduct().getUnit());
            item.setImageUrlSnapshot(inventory.getProduct().getImageUrl());
            item.setPriceSnapshot(inventory.getPrice());
            item.setQuantity(entry.getValue());
            item.setTotalPrice(inventory.getPrice().multiply(BigDecimal.valueOf(entry.getValue()))
                    .setScale(2, RoundingMode.HALF_UP));
            order.addItem(item);
        }
        orderRepository.save(order);

        // Reserve stock only after every item has been validated. Pessimistic locks are
        // still held, so concurrent checkouts cannot pass the same availability check.
        for (Map.Entry<Long, Integer> entry : quantities.entrySet()) {
            ShopInventory inventory = inventoryByProduct.get(entry.getKey());
            inventory.setAvailableQuantity(inventory.getAvailableQuantity() - entry.getValue());
            inventoryRepository.save(inventory);
        }

        Payment payment = new Payment();
        payment.setOrder(order);
        payment.setPaymentMethod(request.paymentMethod());
        payment.setAmount(order.getTotalAmount());
        payment.setPaymentStatus(PaymentStatus.PENDING);
        payment.setGateway(online ? "RAZORPAY" : "COD");
        if (!online) {
            payment.setPaymentReference("COD-" + order.getOrderNumber());
        }
        paymentRepository.save(payment);

        cart.clearItems();
        cart.setSelectedShop(null);
        cartRepository.save(cart);

        if (online) {
            notificationService.notifyUser(customer, "Order created – complete payment",
                    "Order " + order.getOrderNumber() + " is reserved for you. Pay ₹"
                            + order.getTotalAmount().setScale(0) + " to confirm it with "
                            + shop.getName() + ".",
                    "PAYMENT", order.getId(), order.getOrderNumber());
        } else {
            notificationService.notifyUser(customer, "Order placed ✅",
                    "Order " + order.getOrderNumber() + " is confirmed with " + shop.getName()
                            + ". Pay ₹" + order.getTotalAmount().setScale(0) + " on delivery.",
                    "ORDER", order.getId(), order.getOrderNumber());
            notifyShopOwner(order, "New order received",
                    "Order " + order.getOrderNumber() + " from " + customer.getName()
                            + " · ₹" + order.getTotalAmount().setScale(0) + ". Accept it to start packing.",
                    "ORDER");
        }

        return toResponse(order);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> customerOrders() {
        Long customerId = CurrentUser.id();
        return orderRepository.findByCustomerIdOrderByCreatedAtDesc(customerId).stream()
                .map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse customerOrder(Long id) {
        return toResponse(orderRepository.findByIdAndCustomerId(id, CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found.")));
    }

    @Transactional
    public OrderResponse cancelByCustomer(Long id, String reason) {
        ShopOrder order = orderRepository.findByIdAndCustomerId(id, CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
        if (!isCustomerCancellable(order.getOrderStatus())) {
            throw ApiException.conflict("CANCEL_NOT_ALLOWED",
                    "This order can no longer be cancelled. Please contact the shop.");
        }
        String cancellationReason = reason == null || reason.isBlank()
                ? "Cancelled by customer" : reason.trim();
        paymentService.refundIfPaid(order, cancellationReason);
        restoreStock(order);
        order.setOrderStatus(OrderStatus.CANCELLED);
        order.setCancellationReason(cancellationReason);
        markPaymentFailedOrRefunded(order);
        orderRepository.save(order);
        notifyStatus(order, "Order cancelled",
                "Order " + order.getOrderNumber() + " was cancelled. Any reserved stock has been restored.");
        notifyShopOwner(order, "Order cancelled by customer",
                "Order " + order.getOrderNumber() + " was cancelled by " + order.getCustomer().getName()
                        + ". Reserved stock has been restored.",
                "ORDER");
        return toResponse(order);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> shopOrders(Long shopId, OrderStatus status) {
        List<ShopOrder> orders = status == null
                ? orderRepository.findByShopIdOrderByCreatedAtDesc(shopId)
                : orderRepository.findByShopIdAndOrderStatusOrderByCreatedAtDesc(shopId, status);
        return orders.stream().map(this::toResponse).toList();
    }

    @Transactional
    public OrderResponse updateStatusByOwner(Long orderId, UpdateOrderStatusRequest request, Shop ownerShop) {
        ShopOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
        if (!order.getShop().getId().equals(ownerShop.getId())) {
            throw ApiException.forbidden("You can only manage orders for your own shop.");
        }
        OrderStatus target = request.status();
        if (target == order.getOrderStatus()) {
            return toResponse(order);
        }
        if (!isOwnerTransitionAllowed(order.getOrderStatus(), target)) {
            throw ApiException.conflict("INVALID_STATUS_TRANSITION",
                    "Cannot change order status from " + order.getOrderStatus() + " to " + target + ".");
        }
        if (target == OrderStatus.REJECTED || target == OrderStatus.CANCELLED) {
            String cancellationReason = request.reason() == null || request.reason().isBlank()
                    ? "Rejected by shop" : request.reason().trim();
            paymentService.refundIfPaid(order, cancellationReason);
            restoreStock(order);
            order.setCancellationReason(cancellationReason);
            markPaymentFailedOrRefunded(order);
        }
        if (target == OrderStatus.DELIVERED && order.getPaymentMethod() == PaymentMethod.COD) {
            paymentService.markCodPaid(order);
        }
        order.setOrderStatus(target);
        orderRepository.save(order);
        notifyCustomerOfStatus(order, target);
        if (target == OrderStatus.READY_FOR_PICKUP) {
            notificationService.notifyRole(com.puranabazaar.user.Role.DELIVERY_PARTNER,
                    "Pickup available",
                    "Order " + order.getOrderNumber() + " is ready for pickup at "
                            + order.getShop().getName() + ".",
                    "DELIVERY", order.getId(), order.getOrderNumber());
        }
        return toResponse(order);
    }

    @Transactional
    public OrderResponse cancelByAdmin(Long orderId, String reason) {
        ShopOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
        if (order.getOrderStatus() == OrderStatus.DELIVERED || order.getOrderStatus() == OrderStatus.CANCELLED
                || order.getOrderStatus() == OrderStatus.REJECTED) {
            throw ApiException.conflict("CANCEL_NOT_ALLOWED", "This order cannot be cancelled.");
        }
        String cancellationReason = reason == null || reason.isBlank()
                ? "Cancelled by administrator" : reason.trim();
        paymentService.refundIfPaid(order, cancellationReason);
        restoreStock(order);
        order.setOrderStatus(OrderStatus.CANCELLED);
        order.setCancellationReason(cancellationReason);
        markPaymentFailedOrRefunded(order);
        orderRepository.save(order);
        notifyStatus(order, "Order cancelled",
                "Order " + order.getOrderNumber() + " was cancelled by Purana Bazaar support.");
        notifyShopOwner(order, "Order cancelled by admin",
                "Order " + order.getOrderNumber() + " was cancelled. " + cancellationReason,
                "ORDER");
        return toResponse(order);
    }

    /**
     * Cancels online orders whose payment never completed and releases the
     * reserved stock. Called by the scheduled payment expiry job.
     */
    @Transactional
    public int expireUnpaidOnlineOrders() {
        Instant cutoff = Instant.now().minus(Duration.ofMinutes(Math.max(5, pendingTimeoutMinutes)));
        List<ShopOrder> stale = orderRepository
                .findByOrderStatusAndCreatedAtBefore(OrderStatus.PAYMENT_PENDING, cutoff);
        int expired = 0;
        for (ShopOrder order : stale) {
            if (order.getPaymentMethod() != PaymentMethod.ONLINE
                    || order.getPaymentStatus() == PaymentStatus.PAID) {
                continue;
            }
            restoreStock(order);
            order.setOrderStatus(OrderStatus.CANCELLED);
            order.setCancellationReason("Payment was not completed in time.");
            markPaymentFailedOrRefunded(order);
            paymentService.markPaymentExpired(order);
            orderRepository.save(order);
            notifyStatus(order, "Order expired",
                    "Order " + order.getOrderNumber() + " was cancelled because the payment was not completed. "
                            + "Reserved stock was released.");
            expired++;
        }
        return expired;
    }

    public OrderResponse toResponse(ShopOrder order) {
        return orderMapper.toResponse(order);
    }

    private void notifyCustomerOfStatus(ShopOrder order, OrderStatus target) {
        String title;
        String body;
        switch (target) {
            case ACCEPTED -> {
                title = "Order accepted";
                body = order.getShop().getName() + " accepted order " + order.getOrderNumber()
                        + " and will start packing it.";
            }
            case PREPARING -> {
                title = "Your order is being packed";
                body = "Order " + order.getOrderNumber() + " is being prepared at "
                        + order.getShop().getName() + ".";
            }
            case READY_FOR_PICKUP -> {
                title = "Ready for pickup";
                body = "Order " + order.getOrderNumber() + " is packed and waiting for a delivery partner.";
            }
            case OUT_FOR_DELIVERY -> {
                title = "Out for delivery 🛵";
                body = "Order " + order.getOrderNumber() + " is on its way to you.";
            }
            case DELIVERED -> {
                title = "Delivered 🎉";
                body = "Order " + order.getOrderNumber() + " has been delivered. Enjoy your groceries!";
            }
            case REJECTED -> {
                title = "Order rejected";
                body = "Unfortunately " + order.getShop().getName() + " could not accept order "
                        + order.getOrderNumber() + ". Any payment will be refunded.";
            }
            case CANCELLED -> {
                title = "Order cancelled";
                body = "Order " + order.getOrderNumber() + " was cancelled by the shop.";
            }
            default -> {
                return;
            }
        }
        notifyStatus(order, title, body);
    }

    private void notifyStatus(ShopOrder order, String title, String body) {
        notificationService.notifyUser(order.getCustomer(), title, body, "ORDER",
                order.getId(), order.getOrderNumber());
    }

    private void notifyShopOwner(ShopOrder order, String title, String body, String type) {
        notificationService.notifyUser(order.getShop().getOwner(), title, body, type,
                order.getId(), order.getOrderNumber());
    }

    private void restoreStock(ShopOrder order) {
        if (order.isStockRestored()) {
            return;
        }
        List<Long> ids = order.getItems().stream()
                .map(item -> item.getShopInventory().getId()).sorted().toList();
        List<ShopInventory> inventories = inventoryRepository.lockAllById(ids);
        Map<Long, ShopInventory> byId = new HashMap<>();
        for (ShopInventory inventory : inventories) {
            byId.put(inventory.getId(), inventory);
        }
        for (OrderItem item : order.getItems()) {
            ShopInventory inventory = byId.get(item.getShopInventory().getId());
            if (inventory != null) {
                inventory.setAvailableQuantity(inventory.getAvailableQuantity() + item.getQuantity());
                inventoryRepository.save(inventory);
            }
        }
        order.setStockRestored(true);
    }

    private void markPaymentFailedOrRefunded(ShopOrder order) {
        PaymentStatus newStatus = order.getPaymentStatus() == PaymentStatus.PAID
                || order.getPaymentStatus() == PaymentStatus.REFUNDED
                ? PaymentStatus.REFUNDED : PaymentStatus.FAILED;
        order.setPaymentStatus(newStatus);
        paymentRepository.findByOrderId(order.getId()).ifPresent(payment -> {
            payment.setPaymentStatus(newStatus);
            payment.setUpdatedAt(Instant.now());
            paymentRepository.save(payment);
        });
    }

    private void validateShopDelivery(Shop shop, double latitude, double longitude) {
        if (shop.getApprovalStatus() != ShopApprovalStatus.APPROVED
                || shop.getOperationalStatus() != ShopOperationalStatus.ACTIVE) {
            throw ApiException.conflict("SHOP_UNAVAILABLE", "This shop is not accepting orders right now.");
        }
        if (!shop.isDeliveryAvailable()) {
            throw ApiException.conflict("DELIVERY_UNAVAILABLE", "This shop does not offer delivery.");
        }
        if (!shop.isOpenAt(LocalTime.now(zoneId))) {
            throw ApiException.conflict("SHOP_CLOSED", "This shop is currently closed.");
        }
        double distance = GeoUtils.distanceKm(latitude, longitude, shop.getLatitude(), shop.getLongitude());
        if (distance > shop.getDeliveryRadius()) {
            throw ApiException.conflict("OUTSIDE_DELIVERY_RADIUS",
                    "The shop is outside its delivery radius for this address.");
        }
    }

    private void collectQuantities(Cart cart, Map<Long, Integer> quantities) {
        for (CartItem item : cart.getItems()) {
            if (item.getProduct() == null) {
                throw ApiException.conflict("INVALID_CART", "Cart item is missing a product.");
            }
            quantities.merge(item.getProduct().getId(), item.getQuantity(), Integer::sum);
        }
    }

    private boolean isCustomerCancellable(OrderStatus status) {
        return OrderMapper.isCustomerCancellable(status);
    }

    private boolean isOwnerTransitionAllowed(OrderStatus current, OrderStatus target) {
        return switch (current) {
            case PENDING -> target == OrderStatus.ACCEPTED || target == OrderStatus.REJECTED
                    || target == OrderStatus.CANCELLED;
            case ACCEPTED -> target == OrderStatus.PREPARING || target == OrderStatus.CANCELLED;
            case PREPARING -> target == OrderStatus.READY_FOR_PICKUP || target == OrderStatus.CANCELLED;
            case READY_FOR_PICKUP -> target == OrderStatus.OUT_FOR_DELIVERY;
            case OUT_FOR_DELIVERY -> target == OrderStatus.DELIVERED;
            default -> false;
        };
    }

    private String newOrderNumber() {
        String date = LocalDate.now(zoneId).format(DateTimeFormatter.ofPattern("yyMMdd"));
        String random = UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase(Locale.ROOT);
        return "PB" + date + random;
    }
}
