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
import com.puranabazaar.order.dto.*;
import com.puranabazaar.payment.Payment;
import com.puranabazaar.payment.PaymentRepository;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.*;
import com.puranabazaar.user.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
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
    private final ShopMapper shopMapper;
    private final ZoneId zoneId;

    public OrderService(OrderRepository orderRepository, CartRepository cartRepository,
                        CustomerAddressRepository addressRepository, ShopRepository shopRepository,
                        ShopInventoryRepository inventoryRepository, PaymentRepository paymentRepository,
                        ShopSelectionService selectionService, DeliveryFeeCalculator feeCalculator,
                        ShopMapper shopMapper,
                        @Value("${app.timezone:Asia/Kolkata}") String timezone) {
        this.orderRepository = orderRepository;
        this.cartRepository = cartRepository;
        this.addressRepository = addressRepository;
        this.shopRepository = shopRepository;
        this.inventoryRepository = inventoryRepository;
        this.paymentRepository = paymentRepository;
        this.selectionService = selectionService;
        this.feeCalculator = feeCalculator;
        this.shopMapper = shopMapper;
        this.zoneId = ZoneId.of(timezone);
    }

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        User customer = CurrentUser.require();
        Optional<ShopOrder> replay = orderRepository.findByCustomerIdAndIdempotencyKey(
                customer.getId(), request.idempotencyKey());
        if (replay.isPresent()) {
            return toResponse(replay.get());
        }
        if (request.paymentMethod() == PaymentMethod.ONLINE) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ONLINE_PAYMENT_NOT_CONFIGURED",
                    "Online payment is not enabled yet. Please choose Cash on Delivery.");
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
        order.setOrderStatus(OrderStatus.PENDING);
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
        paymentRepository.save(payment);

        cart.clearItems();
        cart.setSelectedShop(null);
        cartRepository.save(cart);

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
        restoreStock(order);
        order.setOrderStatus(OrderStatus.CANCELLED);
        order.setCancellationReason(reason == null || reason.isBlank()
                ? "Cancelled by customer" : reason.trim());
        markPaymentFailedOrRefunded(order);
        orderRepository.save(order);
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
            restoreStock(order);
            order.setCancellationReason(request.reason() == null || request.reason().isBlank()
                    ? "Rejected by shop" : request.reason().trim());
            markPaymentFailedOrRefunded(order);
        }
        if (target == OrderStatus.DELIVERED) {
            order.setPaymentStatus(PaymentStatus.PAID);
            paymentRepository.findByOrderId(order.getId()).ifPresent(payment -> {
                payment.setPaymentStatus(PaymentStatus.PAID);
                payment.setPaymentReference("COD-" + order.getOrderNumber());
                payment.setUpdatedAt(java.time.Instant.now());
                paymentRepository.save(payment);
            });
        }
        order.setOrderStatus(target);
        orderRepository.save(order);
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
        restoreStock(order);
        order.setOrderStatus(OrderStatus.CANCELLED);
        order.setCancellationReason(reason == null || reason.isBlank()
                ? "Cancelled by administrator" : reason.trim());
        markPaymentFailedOrRefunded(order);
        orderRepository.save(order);
        return toResponse(order);
    }

    public OrderResponse toResponse(ShopOrder order) {
        List<OrderItemResponse> items = order.getItems().stream()
                .map(item -> new OrderItemResponse(item.getId(), item.getProduct().getId(),
                        item.getProductNameSnapshot(), item.getBrandSnapshot(), item.getUnitSnapshot(),
                        item.getImageUrlSnapshot(), item.getPriceSnapshot(), item.getQuantity(),
                        item.getTotalPrice()))
                .toList();
        return new OrderResponse(
                order.getId(),
                order.getOrderNumber(),
                order.getShoppingMode().name(),
                order.getOrderStatus().name(),
                order.getPaymentStatus().name(),
                order.getPaymentMethod().name(),
                shopMapper.toResponse(order.getShop(), order.getDeliveryLatitude(), order.getDeliveryLongitude()),
                order.getCustomer().getName(),
                order.getCustomer().getPhone(),
                order.getDeliveryPartner() == null ? null : order.getDeliveryPartner().getName(),
                order.getDeliveryPartner() == null ? null : order.getDeliveryPartner().getPhone(),
                order.getDeliveryAddress(),
                order.getDeliveryLatitude(),
                order.getDeliveryLongitude(),
                order.getSubtotal(),
                order.getDeliveryCharge(),
                order.getTotalAmount(),
                items,
                order.getCustomerNote(),
                order.getCancellationReason(),
                isCustomerCancellable(order.getOrderStatus()),
                order.getCreatedAt(),
                order.getUpdatedAt()
        );
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
                ? PaymentStatus.REFUNDED : PaymentStatus.FAILED;
        order.setPaymentStatus(newStatus);
        paymentRepository.findByOrderId(order.getId()).ifPresent(payment -> {
            payment.setPaymentStatus(newStatus);
            payment.setUpdatedAt(java.time.Instant.now());
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
        return status == OrderStatus.PENDING || status == OrderStatus.ACCEPTED
                || status == OrderStatus.PREPARING || status == OrderStatus.PAYMENT_PENDING;
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
