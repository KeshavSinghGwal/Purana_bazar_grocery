package com.puranabazaar.cart;

import com.puranabazaar.cart.dto.AddCartItemRequest;
import com.puranabazaar.cart.dto.CartItemResponse;
import com.puranabazaar.cart.dto.CartResponse;
import com.puranabazaar.catalog.CatalogService;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.common.DeliveryFeeCalculator;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.ShopMapper;
import com.puranabazaar.shop.ShopOperationalStatus;
import com.puranabazaar.user.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class CartService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final ProductRepository productRepository;
    private final ShopInventoryRepository inventoryRepository;
    private final CatalogService catalogService;
    private final ShopMapper shopMapper;
    private final DeliveryFeeCalculator feeCalculator;

    public CartService(CartRepository cartRepository, CartItemRepository cartItemRepository,
                       ProductRepository productRepository, ShopInventoryRepository inventoryRepository,
                       CatalogService catalogService, ShopMapper shopMapper,
                       DeliveryFeeCalculator feeCalculator) {
        this.cartRepository = cartRepository;
        this.cartItemRepository = cartItemRepository;
        this.productRepository = productRepository;
        this.inventoryRepository = inventoryRepository;
        this.catalogService = catalogService;
        this.shopMapper = shopMapper;
        this.feeCalculator = feeCalculator;
    }

    @Transactional(readOnly = true)
    public CartResponse getCart() {
        Long customerId = CurrentUser.id();
        return cartRepository.findByCustomerIdWithItems(customerId)
                .map(cart -> toResponse(cart, null, null))
                .orElseGet(CartService::emptyResponse);
    }

    @Transactional
    public CartResponse addItem(AddCartItemRequest request) {
        User customer = CurrentUser.require();
        Cart cart = cartRepository.findByCustomerIdWithItems(customer.getId()).orElseGet(() -> {
            Cart created = new Cart();
            created.setCustomer(customer);
            created.setShoppingMode(request.shoppingMode());
            return created;
        });

        if (!cart.getItems().isEmpty()
                && (cart.getShoppingMode() != request.shoppingMode()
                || (request.shoppingMode() == ShoppingMode.SHOP_CHOICE
                && (cart.getSelectedShop() == null || !cart.getSelectedShop().getId().equals(resolveShopId(request)))))) {
            throw ApiException.conflict("CART_MODE_CONFLICT",
                    cart.getShoppingMode() == ShoppingMode.SHOP_CHOICE
                            ? "Your cart already contains items from " + cart.getSelectedShop().getName()
                            + ". Clear the cart before shopping from another shop."
                            : "Your cart already contains Product Choice items. Clear the cart before switching to Shop Choice.",
                    Map.of("currentMode", cart.getShoppingMode().name(),
                            "selectedShopId", cart.getSelectedShop() == null ? "" : cart.getSelectedShop().getId()));
        }

        if (request.shoppingMode() == ShoppingMode.PRODUCT_CHOICE) {
            return addProductChoiceItem(cart, request);
        }
        return addShopChoiceItem(cart, request);
    }

    @Transactional
    public CartResponse updateQuantity(Long itemId, int quantity) {
        Cart cart = currentCart();
        CartItem item = cart.getItems().stream()
                .filter(i -> i.getId().equals(itemId))
                .findFirst()
                .orElseThrow(() -> ApiException.notFound("CART_ITEM_NOT_FOUND", "Cart item not found."));
        if (quantity < 1 || quantity > 99) {
            throw ApiException.badRequest("INVALID_QUANTITY", "Quantity must be between 1 and 99.");
        }
        if (cart.getShoppingMode() == ShoppingMode.SHOP_CHOICE) {
            ShopInventory inventory = item.getShopInventory();
            if (inventory == null || !inventory.isActive()) {
                throw ApiException.conflict("ITEM_UNAVAILABLE", "This item is no longer available at the shop.");
            }
            if (quantity > inventory.getAvailableQuantity()) {
                throw ApiException.conflict("INSUFFICIENT_STOCK",
                        "Only " + inventory.getAvailableQuantity() + " units are available at this shop.");
            }
        }
        item.setQuantity(quantity);
        cartRepository.save(cart);
        return toResponse(cart, null, null);
    }

    @Transactional
    public CartResponse removeItem(Long itemId) {
        Cart cart = currentCart();
        boolean removed = cart.getItems().removeIf(item -> item.getId().equals(itemId));
        if (!removed) {
            throw ApiException.notFound("CART_ITEM_NOT_FOUND", "Cart item not found.");
        }
        if (cart.getItems().isEmpty()) {
            cart.setSelectedShop(null);
        }
        cartRepository.save(cart);
        return toResponse(cart, null, null);
    }

    @Transactional
    public CartResponse clear() {
        return cartRepository.findByCustomerIdWithItems(CurrentUser.id())
                .map(cart -> {
                    cart.clearItems();
                    cart.setSelectedShop(null);
                    cartRepository.save(cart);
                    return toResponse(cart, null, null);
                })
                .orElseGet(CartService::emptyResponse);
    }

    @Transactional(readOnly = true)
    public Cart requireCart() {
        return cartRepository.findByCustomerIdWithItems(CurrentUser.id())
                .filter(cart -> !cart.getItems().isEmpty())
                .orElseThrow(() -> ApiException.badRequest("CART_EMPTY", "Your cart is empty."));
    }

    public CartResponse toResponse(Cart cart, Double latitude, Double longitude) {
        Map<Long, CatalogService.Availability> availability = cart.getShoppingMode() == ShoppingMode.PRODUCT_CHOICE
                ? catalogService.availability() : Map.of();
        List<CartItemResponse> items = cart.getItems().stream()
                .map(item -> toItemResponse(item, availability))
                .toList();
        BigDecimal subtotal = items.stream()
                .map(CartItemResponse::lineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal delivery = feeCalculator.feeFor(subtotal);
        boolean issues = items.stream().anyMatch(item -> !item.available() || item.quantity() > item.availableQuantity());
        int count = items.stream().mapToInt(CartItemResponse::quantity).sum();
        Shop selectedShop = cart.getSelectedShop();
        return new CartResponse(
                cart.getId(),
                cart.getShoppingMode() == null ? null : cart.getShoppingMode().name(),
                selectedShop == null ? null : shopMapper.toResponse(selectedShop, latitude, longitude),
                items,
                count,
                subtotal,
                delivery,
                subtotal.add(delivery),
                issues,
                cart.getShoppingMode() == ShoppingMode.PRODUCT_CHOICE
                        ? "Best nearby prices shown. The shop and final prices are confirmed at checkout."
                        : null
        );
    }

    private CartResponse addProductChoiceItem(Cart cart, AddCartItemRequest request) {
        if (request.productId() == null) {
            throw ApiException.badRequest("PRODUCT_REQUIRED", "productId is required for Product Choice.");
        }
        Product product = productRepository.findByIdAndActiveTrue(request.productId())
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        boolean stocked = inventoryRepository.findAvailableForProducts(List.of(product.getId())).stream()
                .anyMatch(inv -> inv.getAvailableQuantity() >= request.quantity());
        if (!stocked) {
            throw ApiException.conflict("OUT_OF_STOCK", "No nearby shop currently has this product in stock.");
        }
        if (cart.getItems().isEmpty()) {
            cart.setShoppingMode(ShoppingMode.PRODUCT_CHOICE);
            cart.setSelectedShop(null);
        }
        CartItem item = cart.getItems().stream()
                .filter(i -> i.getProduct() != null && i.getProduct().getId().equals(product.getId()))
                .findFirst()
                .orElseGet(() -> {
                    CartItem created = new CartItem();
                    created.setProduct(product);
                    cart.addItem(created);
                    return created;
                });
        int newQuantity = item.getQuantity() + request.quantity();
        if (newQuantity > 99) {
            throw ApiException.badRequest("INVALID_QUANTITY", "Maximum quantity per item is 99.");
        }
        item.setQuantity(newQuantity);
        cartRepository.save(cart);
        return toResponse(cart, null, null);
    }

    private CartResponse addShopChoiceItem(Cart cart, AddCartItemRequest request) {
        if (request.shopInventoryId() == null) {
            throw ApiException.badRequest("INVENTORY_REQUIRED", "shopInventoryId is required for Shop Choice.");
        }
        ShopInventory inventory = inventoryRepository.findById(request.shopInventoryId())
                .orElseThrow(() -> ApiException.notFound("INVENTORY_NOT_FOUND", "Shop listing not found."));
        validateShopInventory(inventory);
        if (cart.getItems().isEmpty()) {
            cart.setShoppingMode(ShoppingMode.SHOP_CHOICE);
            cart.setSelectedShop(inventory.getShop());
        }
        if (cart.getSelectedShop() == null || !cart.getSelectedShop().getId().equals(inventory.getShop().getId())) {
            throw ApiException.conflict("CART_SHOP_CONFLICT",
                    "Your cart contains products from another shop. Clear the cart to shop from "
                            + inventory.getShop().getName() + ".");
        }
        CartItem item = cart.getItems().stream()
                .filter(i -> i.getShopInventory() != null
                        && i.getShopInventory().getId().equals(inventory.getId()))
                .findFirst()
                .orElseGet(() -> {
                    CartItem created = new CartItem();
                    created.setShopInventory(inventory);
                    created.setProduct(inventory.getProduct());
                    cart.addItem(created);
                    return created;
                });
        int newQuantity = item.getQuantity() + request.quantity();
        if (newQuantity > inventory.getAvailableQuantity()) {
            throw ApiException.conflict("INSUFFICIENT_STOCK",
                    "Only " + inventory.getAvailableQuantity() + " units are available at this shop.");
        }
        item.setQuantity(newQuantity);
        cartRepository.save(cart);
        return toResponse(cart, null, null);
    }

    private void validateShopInventory(ShopInventory inventory) {
        Shop shop = inventory.getShop();
        if (!inventory.isActive() || !inventory.getProduct().isActive()) {
            throw ApiException.conflict("ITEM_UNAVAILABLE", "This product is not available at the shop.");
        }
        if (shop.getApprovalStatus() != ShopApprovalStatus.APPROVED
                || shop.getOperationalStatus() != ShopOperationalStatus.ACTIVE) {
            throw ApiException.conflict("SHOP_UNAVAILABLE", "This shop is not accepting orders right now.");
        }
        if (inventory.getAvailableQuantity() <= 0) {
            throw ApiException.conflict("OUT_OF_STOCK", "This product is out of stock at this shop.");
        }
    }

    private CartItemResponse toItemResponse(CartItem item, Map<Long, CatalogService.Availability> availability) {
        Product product = item.getProduct();
        BigDecimal unitPrice;
        int availableQuantity;
        Long inventoryId = null;
        Long shopId = null;
        boolean available;
        if (item.getShopInventory() != null) {
            ShopInventory inventory = item.getShopInventory();
            inventoryId = inventory.getId();
            shopId = inventory.getShop().getId();
            unitPrice = inventory.getPrice();
            availableQuantity = inventory.getAvailableQuantity();
            available = inventory.isActive() && inventory.getProduct().isActive()
                    && availableQuantity >= item.getQuantity();
        } else {
            CatalogService.Availability stats = availability.get(product.getId());
            unitPrice = stats != null && stats.bestPrice() != null ? stats.bestPrice() : BigDecimal.ZERO;
            availableQuantity = stats != null ? stats.totalStock() : 0;
            available = stats != null && stats.availableShops() > 0 && availableQuantity >= item.getQuantity();
        }
        BigDecimal lineTotal = unitPrice.multiply(BigDecimal.valueOf(item.getQuantity()))
                .setScale(2, RoundingMode.HALF_UP);
        return new CartItemResponse(item.getId(), product.getId(), inventoryId, shopId,
                product.getName(), product.getBrand(), product.getUnit(), product.getImageUrl(),
                item.getQuantity(), unitPrice, lineTotal, availableQuantity, available,
                product.getCategory().getId(), product.getCategory().getName());
    }

    private Long resolveShopId(AddCartItemRequest request) {
        if (request.shopInventoryId() == null) {
            return null;
        }
        return inventoryRepository.findById(request.shopInventoryId())
                .map(inv -> inv.getShop().getId())
                .orElse(null);
    }

    private Cart currentCart() {
        Long customerId = CurrentUser.id();
        return cartRepository.findByCustomerIdWithItems(customerId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CART_NOT_FOUND", "Your cart is empty."));
    }

    private static CartResponse emptyResponse() {
        return new CartResponse(null, null, null, List.of(), 0,
                BigDecimal.ZERO.setScale(2), BigDecimal.ZERO.setScale(2), BigDecimal.ZERO.setScale(2),
                false, null);
    }

    public Map<Long, Integer> cartQuantitiesByProduct(Cart cart) {
        Map<Long, Integer> quantities = new HashMap<>();
        for (CartItem item : cart.getItems()) {
            if (item.getProduct() != null) {
                quantities.merge(item.getProduct().getId(), item.getQuantity(), Integer::sum);
            }
        }
        return quantities;
    }
}
