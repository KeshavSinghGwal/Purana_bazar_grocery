package com.puranabazaar;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.puranabazaar.address.CustomerAddress;
import com.puranabazaar.address.CustomerAddressRepository;
import com.puranabazaar.catalog.Category;
import com.puranabazaar.catalog.CategoryRepository;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.shop.*;
import com.puranabazaar.user.Role;
import com.puranabazaar.user.User;
import com.puranabazaar.user.UserRepository;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class MarketplaceFlowIntegrationTest {

    @Value("${local.server.port}")
    private int port;

    @Autowired private UserRepository userRepository;
    @Autowired private ShopRepository shopRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private ProductRepository productRepository;
    @Autowired private ShopInventoryRepository inventoryRepository;
    @Autowired private CustomerAddressRepository addressRepository;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private ObjectMapper objectMapper;

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15)).build();

    private User admin, customer, otherCustomer, ownerA, ownerB, ownerC, deliveryPartner;
    private Shop shopA, shopB, shopC;
    private Product productA, productB, productD, productE, productG;
    private ShopInventory invAProductA, invBProductA, invAProductB, invBProductD, invCProductE, invAProductG;
    private CustomerAddress address;
    private String adminToken, customerToken, otherCustomerToken, ownerAToken, ownerBToken, deliveryToken;
    private Long orderBId;
    private Long orderDId;

    @BeforeAll
    void setUp() throws Exception {
        admin = user("Integration Admin", "it-admin@purana.test", "9000000100", Role.ADMIN);
        customer = user("Integration Customer", "it-customer@purana.test", "9000000101", Role.CUSTOMER);
        otherCustomer = user("Other Customer", "it-other@purana.test", "9000000102", Role.CUSTOMER);
        ownerA = user("Owner A", "it-owner-a@purana.test", "9000000103", Role.SHOP_OWNER);
        ownerB = user("Owner B", "it-owner-b@purana.test", "9000000104", Role.SHOP_OWNER);
        ownerC = user("Owner C", "it-owner-c@purana.test", "9000000105", Role.SHOP_OWNER);
        deliveryPartner = user("Delivery Partner", "it-delivery@purana.test", "9000000107",
                Role.DELIVERY_PARTNER);

        Category category = new Category();
        category.setName("Integration Category " + System.nanoTime());
        category.setActive(true);
        category = categoryRepository.save(category);

        productA = product(category, "Scenario A Product");
        productB = product(category, "Scenario B Product");
        productD = product(category, "Scenario D Product");
        productE = product(category, "Scenario E Product");
        productG = product(category, "Scenario G Product");

        shopA = shop(ownerA, "Integration Shop A", 22.7540, 75.8945, 10.0);
        shopB = shop(ownerB, "Integration Shop B", 22.7700, 75.8937, 10.0);
        shopC = shop(ownerC, "Integration Shop C", 22.8000, 75.8937, 2.0);

        invAProductA = inventory(shopA, productA, "100.00", 1);
        invBProductA = inventory(shopB, productA, "95.00", 10);
        invAProductB = inventory(shopA, productB, "50.00", 10);
        invBProductD = inventory(shopB, productD, "200.00", 5);
        invCProductE = inventory(shopC, productE, "80.00", 10);
        invAProductG = inventory(shopA, productG, "60.00", 1);

        address = new CustomerAddress();
        address.setCustomer(customer);
        address.setLabel("Test Home");
        address.setAddressLine("1, Test Residency, Vijay Nagar");
        address.setCity("Indore");
        address.setState("Madhya Pradesh");
        address.setPostalCode("452010");
        address.setLatitude(22.7533);
        address.setLongitude(75.8937);
        address.setDefaultAddress(true);
        addressRepository.save(address);

        adminToken = login("it-admin@purana.test", "Admin@123");
        customerToken = login("it-customer@purana.test", "Customer@123");
        otherCustomerToken = login("it-other@purana.test", "Customer@123");
        ownerAToken = login("it-owner-a@purana.test", "Owner@123");
        ownerBToken = login("it-owner-b@purana.test", "Owner@123");
        deliveryToken = login("it-delivery@purana.test", "Delivery@123");
    }

    @Test
    @Order(1)
    @DisplayName("Scenario A: nearest shop with insufficient stock is skipped")
    void scenarioA() throws Exception {
        clearCart();
        addProductChoice(productA.getId(), 3);

        JsonNode quote = call("POST", "/api/marketplace/find-shop", customerToken,
                Map.of("addressId", address.getId()), 200);

        assertTrue(quote.get("found").asBoolean());
        assertEquals(shopB.getId(), quote.get("selectedShop").get("id").asLong(),
                "The second-nearest shop must be selected when the nearest cannot fulfil the cart");
        assertEquals(3, quote.get("items").get(0).get("requestedQuantity").asInt());
        assertTrue(quote.get("distanceKm").asDouble() > 1.0);
        assertEquals(0, new BigDecimal("285.00").compareTo(quote.get("subtotal").decimalValue()));
    }

    @Test
    @Order(2)
    @DisplayName("Scenario E: shop outside its delivery radius is never selected")
    void scenarioE() throws Exception {
        clearCart();
        addProductChoice(productE.getId(), 1);

        JsonNode quote = call("POST", "/api/marketplace/find-shop", customerToken,
                Map.of("addressId", address.getId()), 200);

        assertFalse(quote.get("found").asBoolean());
        String candidateReason = quote.get("consideredShops").toString();
        assertTrue(candidateReason.contains("Outside delivery radius"), candidateReason);
    }

    @Test
    @Order(3)
    @DisplayName("Scenario G: no eligible shop returns a useful message and unavailable product details")
    void scenarioG() throws Exception {
        clearCart();
        addProductChoice(productG.getId(), 1);

        Map<String, Object> body = new HashMap<>();
        body.put("addressId", address.getId());
        body.put("items", List.of(Map.of("productId", productG.getId(), "quantity", 3)));
        JsonNode quote = call("POST", "/api/marketplace/find-shop", customerToken, body, 200);

        assertFalse(quote.get("found").asBoolean());
        assertTrue(quote.get("message").asText().contains("No nearby shop"));
        assertEquals(1, quote.get("unavailableProducts").size());
        assertEquals(1, quote.get("unavailableProducts").get(0).get("maxAvailable").asInt());
    }

    @Test
    @Order(4)
    @DisplayName("Scenario B: Shop Choice keeps the customer's shop and decrements its stock")
    void scenarioB() throws Exception {
        clearCart();
        JsonNode cart = call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invAProductB.getId(),
                "quantity", 2), 201);
        assertEquals("SHOP_CHOICE", cart.get("shoppingMode").asText());
        assertEquals(shopA.getId(), cart.get("selectedShop").get("id").asLong());

        JsonNode quote = call("POST", "/api/marketplace/checkout/validate", customerToken,
                Map.of("addressId", address.getId()), 200);
        assertTrue(quote.get("found").asBoolean());
        assertEquals(shopA.getId(), quote.get("selectedShop").get("id").asLong());

        JsonNode order = createOrder("it-shop-choice");
        assertEquals(shopA.getId(), order.get("shop").get("id").asLong());
        assertEquals("SHOP_CHOICE", order.get("shoppingMode").asText());
        orderBId = order.get("id").asLong();

        ShopInventory refreshed = inventoryRepository.findById(invAProductB.getId()).orElseThrow();
        assertEquals(8, refreshed.getAvailableQuantity());

        JsonNode replay = createOrder("it-shop-choice");
        assertEquals(order.get("id").asLong(), replay.get("id").asLong(),
                "Repeated checkout with the same idempotency key must return the original order");
        assertEquals(8, inventoryRepository.findById(invAProductB.getId()).orElseThrow().getAvailableQuantity());
    }

    @Test
    @Order(5)
    @DisplayName("Scenario D: stock is decremented transactionally and cannot be oversold")
    void scenarioD() throws Exception {
        clearCart();
        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invBProductD.getId(),
                "quantity", 3), 201);
        JsonNode order = createOrder("it-stock-1");
        orderDId = order.get("id").asLong();
        assertEquals(2, inventoryRepository.findById(invBProductD.getId()).orElseThrow().getAvailableQuantity());

        clearCart();
        JsonNode conflict = call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invBProductD.getId(),
                "quantity", 3), 409);
        assertEquals("INSUFFICIENT_STOCK", conflict.get("code").asText());

        JsonNode second = call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invBProductD.getId(),
                "quantity", 2), 201);
        assertEquals(2, second.get("items").get(0).get("quantity").asInt());
        createOrder("it-stock-2");
        assertEquals(0, inventoryRepository.findById(invBProductD.getId()).orElseThrow().getAvailableQuantity());

        JsonNode soldOut = call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invBProductD.getId(),
                "quantity", 1), 409);
        assertEquals("OUT_OF_STOCK", soldOut.get("code").asText());
    }

    @Test
    @Order(6)
    @DisplayName("Order lifecycle: owner accepts and completes; invalid transitions are rejected")
    void orderLifecycle() throws Exception {
        JsonNode accepted = call("PUT", "/api/shop-owner/orders/" + orderDId + "/status",
                ownerBToken, Map.of("status", "ACCEPTED"), 200);
        assertEquals("ACCEPTED", accepted.get("orderStatus").asText());

        JsonNode invalid = call("PUT", "/api/shop-owner/orders/" + orderDId + "/status",
                ownerBToken, Map.of("status", "DELIVERED"), 409);
        assertEquals("INVALID_STATUS_TRANSITION", invalid.get("code").asText());

        for (String status : List.of("PREPARING", "READY_FOR_PICKUP", "OUT_FOR_DELIVERY", "DELIVERED")) {
            call("PUT", "/api/shop-owner/orders/" + orderDId + "/status",
                    ownerBToken, Map.of("status", status), 200);
        }
        JsonNode order = call("GET", "/api/orders/" + orderDId, customerToken, null, 200);
        assertEquals("DELIVERED", order.get("orderStatus").asText());
        assertEquals("PAID", order.get("paymentStatus").asText());
    }

    @Test
    @Order(7)
    @DisplayName("Scenario C: a shop stays hidden until admin approval")
    void scenarioC() throws Exception {
        String email = "it-pending-" + System.nanoTime() + "@purana.test";
        String shopName = "Pending Integration Shop " + System.nanoTime();
        JsonNode registration = call("POST", "/api/shop-owner/register", null, Map.ofEntries(
                Map.entry("name", "Pending Owner"),
                Map.entry("email", email),
                Map.entry("phone", "9876543210"),
                Map.entry("password", "Owner@123"),
                Map.entry("shopName", shopName),
                Map.entry("description", "Awaiting approval"),
                Map.entry("address", "9, Pending Road, Indore"),
                Map.entry("latitude", 22.7560),
                Map.entry("longitude", 75.8950),
                Map.entry("openingTime", "00:00:00"),
                Map.entry("closingTime", "00:00:00"),
                Map.entry("deliveryRadius", 5.0),
                Map.entry("shopCategory", "Kirana")
        ), 201);
        assertEquals("PENDING_APPROVAL", registration.get("shopStatus").asText());
        long shopId = registration.get("shopId").asLong();

        JsonNode publicShops = call("GET", "/api/shops", null, null, 200);
        assertFalse(publicShops.toString().contains(shopName), "Pending shop must not be publicly visible");

        JsonNode pending = call("GET", "/api/admin/shops/pending", adminToken, null, 200);
        assertTrue(pending.toString().contains(shopName));

        call("PUT", "/api/admin/shops/" + shopId + "/approve", adminToken, null, 200);
        JsonNode afterApproval = call("GET", "/api/shops", null, null, 200);
        assertTrue(afterApproval.toString().contains(shopName), "Approved shop must appear in public listings");
    }

    @Test
    @Order(8)
    @DisplayName("Scenario F: cross-shop and cross-customer access is denied")
    void scenarioF() throws Exception {
        JsonNode forbidden = call("PUT", "/api/shop-owner/inventory/" + invBProductD.getId(), ownerAToken,
                Map.of("productId", productD.getId(), "price", 1.00, "availableQuantity", 1), 403);
        assertEquals("FORBIDDEN", forbidden.get("code").asText());

        JsonNode crossCustomer = call("GET", "/api/orders/" + orderBId, otherCustomerToken, null, 404);
        assertEquals("ORDER_NOT_FOUND", crossCustomer.get("code").asText());

        JsonNode crossShopOrder = call("PUT", "/api/shop-owner/orders/" + orderBId + "/status",
                ownerBToken, Map.of("status", "ACCEPTED"), 403);
        assertEquals("FORBIDDEN", crossShopOrder.get("code").asText());

        JsonNode otherOwner = call("PUT", "/api/shop-owner/orders/" + orderBId + "/status",
                ownerAToken, Map.of("status", "ACCEPTED"), 200);
        assertEquals("ACCEPTED", otherOwner.get("orderStatus").asText());

        JsonNode unauthenticated = call("GET", "/api/cart", null, null, 401);
        assertEquals("UNAUTHORIZED", unauthenticated.get("code").asText());
    }

    @Test
    @Order(9)
    @DisplayName("Customer cancellation restores stock")
    void cancellationRestoresStock() throws Exception {
        clearCart();
        Product product = product(categoryRepository.findAll().get(0), "Cancellation Product");
        User cancellationOwner = user("Cancellation Owner", "it-cancel-owner@purana.test",
                "9000000106", Role.SHOP_OWNER);
        Shop shop = shop(cancellationOwner, "Cancellation Shop " + System.nanoTime(),
                22.7542, 75.8942, 10.0);
        ShopInventory restockable = inventory(shop, product, "30.00", 4);

        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", restockable.getId(),
                "quantity", 2), 201);
        JsonNode order = createOrder("it-cancel-" + System.nanoTime());
        assertEquals(2, inventoryRepository.findById(restockable.getId()).orElseThrow().getAvailableQuantity());
        call("PUT", "/api/orders/" + order.get("id").asLong() + "/cancel", customerToken,
                Map.of("reason", "Changed my mind"), 200);
        assertEquals(4, inventoryRepository.findById(restockable.getId()).orElseThrow().getAvailableQuantity());
        JsonNode cancelled = call("GET", "/api/orders/" + order.get("id").asLong(), customerToken, null, 200);
        assertEquals("CANCELLED", cancelled.get("orderStatus").asText());
    }

    @Test
    @Order(10)
    @DisplayName("Delivery partner accepts a ready order and completes the delivery")
    void deliveryPartnerFlow() throws Exception {
        clearCart();
        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invAProductB.getId(),
                "quantity", 1), 201);
        JsonNode order = createOrder("it-delivery-" + System.nanoTime());
        long deliveryOrderId = order.get("id").asLong();
        assertEquals(shopA.getId(), order.get("shop").get("id").asLong());

        for (String status : List.of("ACCEPTED", "PREPARING", "READY_FOR_PICKUP")) {
            call("PUT", "/api/shop-owner/orders/" + deliveryOrderId + "/status",
                    ownerAToken, Map.of("status", status), 200);
        }

        JsonNode available = call("GET", "/api/delivery/available", deliveryToken, null, 200);
        assertTrue(available.toString().contains(order.get("orderNumber").asText()),
                "Ready orders must be visible to delivery partners");

        JsonNode accepted = call("PUT", "/api/delivery/orders/" + deliveryOrderId + "/accept",
                deliveryToken, null, 200);
        assertEquals(deliveryPartner.getName(), accepted.get("deliveryPartnerName").asText());

        JsonNode tooSoon = call("PUT", "/api/delivery/orders/" + deliveryOrderId + "/status",
                deliveryToken, Map.of("status", "DELIVERED"), 409);
        assertEquals("INVALID_STATUS_TRANSITION", tooSoon.get("code").asText());

        call("PUT", "/api/delivery/orders/" + deliveryOrderId + "/status",
                deliveryToken, Map.of("status", "OUT_FOR_DELIVERY"), 200);
        call("PUT", "/api/delivery/orders/" + deliveryOrderId + "/status",
                deliveryToken, Map.of("status", "DELIVERED"), 200);

        JsonNode completed = call("GET", "/api/orders/" + deliveryOrderId, customerToken, null, 200);
        assertEquals("DELIVERED", completed.get("orderStatus").asText());
        assertEquals("PAID", completed.get("paymentStatus").asText());

        JsonNode dashboard = call("GET", "/api/delivery/dashboard", deliveryToken, null, 200);
        assertTrue(dashboard.get("completedDeliveries").asLong() >= 1);
        assertEquals(deliveryPartner.getName(), dashboard.get("partnerName").asText());

        JsonNode forbidden = call("GET", "/api/delivery/available", customerToken, null, 403);
        assertEquals("FORBIDDEN", forbidden.get("code").asText());
    }

    @Test
    @Order(11)
    @DisplayName("Online payment: mock Razorpay session, verification, notifications and refund")
    void onlinePaymentFlow() throws Exception {
        clearCart();
        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invAProductB.getId(),
                "quantity", 1), 201);
        int stockBefore = inventoryRepository.findById(invAProductB.getId()).orElseThrow()
                .getAvailableQuantity();

        JsonNode order = createOrder("ONLINE", "it-online-" + System.nanoTime());
        long orderId = order.get("id").asLong();
        assertEquals("ONLINE", order.get("paymentMethod").asText());
        assertEquals("PAYMENT_PENDING", order.get("orderStatus").asText());
        assertEquals("PENDING", order.get("paymentStatus").asText());
        assertTrue(order.get("canRetryPayment").asBoolean());
        assertEquals(stockBefore - 1, inventoryRepository.findById(invAProductB.getId())
                .orElseThrow().getAvailableQuantity(),
                "Stock must be reserved while the online payment is pending");

        JsonNode session = call("POST", "/api/payments/razorpay/order", customerToken,
                Map.of("orderId", orderId), 200);
        assertEquals("RAZORPAY", session.get("gateway").asText());
        assertTrue(session.get("mock").asBoolean());
        assertTrue(session.get("razorpayOrderId").asText().startsWith("order_mock_"));
        assertEquals(order.get("totalAmount").decimalValue()
                        .multiply(BigDecimal.valueOf(100)).longValueExact(),
                session.get("amountPaise").asLong());

        JsonNode rejected = call("POST", "/api/payments/razorpay/verify", customerToken, Map.of(
                "orderId", orderId,
                "razorpayOrderId", session.get("razorpayOrderId").asText(),
                "razorpayPaymentId", "pay_mock_bad",
                "razorpaySignature", "not-a-signature"), 409);
        assertEquals("PAYMENT_VERIFICATION_FAILED", rejected.get("code").asText());

        JsonNode paid = call("POST", "/api/payments/razorpay/verify", customerToken, Map.of(
                "orderId", orderId,
                "razorpayOrderId", session.get("razorpayOrderId").asText(),
                "razorpayPaymentId", "pay_mock_test_123",
                "razorpaySignature", "mock"), 200);
        assertEquals("PENDING", paid.get("orderStatus").asText());
        assertEquals("PAID", paid.get("paymentStatus").asText());

        JsonNode paymentStatus = call("GET", "/api/payments/orders/" + orderId, customerToken, null, 200);
        assertEquals("PAID", paymentStatus.get("paymentStatus").asText());
        assertFalse(paymentStatus.get("retryable").asBoolean());
        assertEquals("pay_mock_test_123", paymentStatus.get("gatewayPaymentId").asText());

        JsonNode notifications = call("GET", "/api/notifications", customerToken, null, 200);
        assertTrue(notifications.toString().contains("Payment successful"),
                "A successful payment must create an in-app notification");
        int unread = call("GET", "/api/notifications/unread-count", customerToken, null, 200)
                .get("count").asInt();
        assertTrue(unread > 0);
        JsonNode unreadList = call("GET", "/api/notifications?unreadOnly=true", customerToken, null, 200);
        long firstUnreadId = unreadList.get(0).get("id").asLong();
        call("PUT", "/api/notifications/" + firstUnreadId + "/read", customerToken, null, 204);
        assertEquals(unread - 1, call("GET", "/api/notifications/unread-count", customerToken, null, 200)
                .get("count").asInt());

        JsonNode cancelled = call("PUT", "/api/orders/" + orderId + "/cancel", customerToken,
                Map.of("reason", "Testing the refund flow"), 200);
        assertEquals("CANCELLED", cancelled.get("orderStatus").asText());
        assertEquals("REFUNDED", cancelled.get("paymentStatus").asText());
        assertEquals(stockBefore, inventoryRepository.findById(invAProductB.getId())
                .orElseThrow().getAvailableQuantity(),
                "Cancelling a paid order must restore reserved stock");
    }

    @Test
    @Order(12)
    @DisplayName("Online payment: a COD order cannot be charged online")
    void onlinePaymentRejectsCodOrder() throws Exception {
        clearCart();
        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "SHOP_CHOICE",
                "shopInventoryId", invAProductB.getId(),
                "quantity", 1), 201);
        JsonNode codOrder = createOrder("it-cod-online-" + System.nanoTime());

        JsonNode error = call("POST", "/api/payments/razorpay/order", customerToken,
                Map.of("orderId", codOrder.get("id").asLong()), 400);
        assertEquals("NOT_AN_ONLINE_ORDER", error.get("code").asText());

        call("PUT", "/api/orders/" + codOrder.get("id").asLong() + "/cancel", customerToken,
                Map.of("reason", "Cleanup"), 200);
    }

    // ---------------------------------------------------------------- helpers

    private User user(String name, String email, String phone, Role role) {
        User user = new User();
        user.setName(name);
        user.setEmail(email);
        user.setPhone(phone);
        user.setPassword(passwordEncoder.encode(role == Role.ADMIN ? "Admin@123"
                : role == Role.SHOP_OWNER ? "Owner@123"
                : role == Role.DELIVERY_PARTNER ? "Delivery@123" : "Customer@123"));
        user.setRole(role);
        user.setActive(true);
        return userRepository.save(user);
    }

    private Product product(Category category, String name) {
        Product product = new Product();
        product.setName(name);
        product.setBrand("Test Brand");
        product.setUnit("1 unit");
        product.setDescription("Integration test product");
        product.setCategory(category);
        product.setActive(true);
        return productRepository.save(product);
    }

    private Shop shop(User owner, String name, double lat, double lng, double radius) {
        Shop shop = new Shop();
        shop.setOwner(owner);
        shop.setName(name);
        shop.setAddress("Integration test address, Indore");
        shop.setLatitude(lat);
        shop.setLongitude(lng);
        shop.setOpeningTime(LocalTime.MIDNIGHT);
        shop.setClosingTime(LocalTime.MIDNIGHT);
        shop.setDeliveryRadius(radius);
        shop.setDeliveryAvailable(true);
        shop.setShopCategory("Kirana");
        shop.setApprovalStatus(ShopApprovalStatus.APPROVED);
        shop.setOperationalStatus(ShopOperationalStatus.ACTIVE);
        shop.setApprovedAt(java.time.Instant.now());
        return shopRepository.save(shop);
    }

    private ShopInventory inventory(Shop shop, Product product, String price, int quantity) {
        ShopInventory inventory = new ShopInventory();
        inventory.setShop(shop);
        inventory.setProduct(product);
        inventory.setPrice(new BigDecimal(price));
        inventory.setAvailableQuantity(quantity);
        inventory.setActive(true);
        return inventoryRepository.save(inventory);
    }

    private String login(String email, String password) throws Exception {
        JsonNode response = call("POST", "/api/auth/login", null,
                Map.of("email", email, "password", password), 200);
        return response.get("token").asText();
    }

    private void clearCart() throws Exception {
        call("DELETE", "/api/cart", customerToken, null, 200);
    }

    private void addProductChoice(Long productId, int quantity) throws Exception {
        call("POST", "/api/cart/items", customerToken, Map.of(
                "shoppingMode", "PRODUCT_CHOICE",
                "productId", productId,
                "quantity", quantity), 201);
    }

    private JsonNode createOrder(String idempotencyKey) throws Exception {
        return createOrder("COD", idempotencyKey);
    }

    private JsonNode createOrder(String paymentMethod, String idempotencyKey) throws Exception {
        return call("POST", "/api/orders", customerToken, Map.of(
                "addressId", address.getId(),
                "paymentMethod", paymentMethod,
                "idempotencyKey", idempotencyKey), 201);
    }

    private JsonNode call(String method, String path, String token, Object body, int expectedStatus)
            throws Exception {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .timeout(Duration.ofSeconds(30))
                .header("Content-Type", "application/json");
        if (token != null) {
            builder.header("Authorization", "Bearer " + token);
        }
        String json = body == null ? null : objectMapper.writeValueAsString(body);
        switch (method) {
            case "GET" -> builder.GET();
            case "POST" -> builder.POST(json == null
                    ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(json));
            case "PUT" -> builder.PUT(json == null
                    ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(json));
            case "DELETE" -> builder.DELETE();
            default -> throw new IllegalArgumentException("Unsupported method " + method);
        }
        HttpResponse<String> response = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(expectedStatus, response.statusCode(),
                () -> method + " " + path + " -> " + response.statusCode() + " " + response.body());
        return response.body() == null || response.body().isBlank()
                ? objectMapper.createObjectNode() : objectMapper.readTree(response.body());
    }
}
