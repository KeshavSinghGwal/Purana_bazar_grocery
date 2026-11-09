package com.puranabazaar.shopowner;

import com.puranabazaar.catalog.*;
import com.puranabazaar.catalog.dto.ProductRequest;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.inventory.dto.InventoryRequest;
import com.puranabazaar.inventory.dto.InventoryResponse;
import com.puranabazaar.order.OrderRepository;
import com.puranabazaar.order.OrderService;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.order.dto.UpdateOrderStatusRequest;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.ShopMapper;
import com.puranabazaar.shop.ShopRepository;
import com.puranabazaar.shop.ShopService;
import com.puranabazaar.shop.dto.ShopResponse;
import com.puranabazaar.shop.dto.ShopUpdateRequest;
import com.puranabazaar.shopowner.dto.OwnerDashboardResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
public class ShopOwnerService {

    private final ShopService shopService;
    private final ShopRepository shopRepository;
    private final ShopMapper shopMapper;
    private final ShopInventoryRepository inventoryRepository;
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final OrderRepository orderRepository;
    private final OrderService orderService;
    private final CatalogService catalogService;

    public ShopOwnerService(ShopService shopService, ShopRepository shopRepository, ShopMapper shopMapper,
                            ShopInventoryRepository inventoryRepository, ProductRepository productRepository,
                            CategoryRepository categoryRepository, OrderRepository orderRepository,
                            OrderService orderService, CatalogService catalogService) {
        this.shopService = shopService;
        this.shopRepository = shopRepository;
        this.shopMapper = shopMapper;
        this.inventoryRepository = inventoryRepository;
        this.productRepository = productRepository;
        this.categoryRepository = categoryRepository;
        this.orderRepository = orderRepository;
        this.orderService = orderService;
        this.catalogService = catalogService;
    }

    @Transactional(readOnly = true)
    public OwnerDashboardResponse dashboard() {
        Shop shop = shopService.requireOwnerShop();
        List<OrderResponse> recent = orderService.shopOrders(shop.getId(), null).stream().limit(6).toList();
        return new OwnerDashboardResponse(
                shop.getId(), shop.getName(), shop.getApprovalStatus().name(),
                shop.getOperationalStatus().name(), shop.getAddress(),
                inventoryRepository.countByShopIdAndActiveTrue(shop.getId()),
                inventoryRepository.countOutOfStock(shop.getId()),
                orderRepository.countByShopId(shop.getId()),
                orderRepository.countByShopIdAndOrderStatus(shop.getId(), OrderStatus.PENDING),
                orderRepository.countByShopIdAndOrderStatus(shop.getId(), OrderStatus.DELIVERED),
                orderRepository.totalDeliveredSalesForShop(shop.getId()).setScale(2, RoundingMode.HALF_UP),
                recent
        );
    }

    @Transactional(readOnly = true)
    public ShopResponse shopProfile() {
        Shop shop = shopService.requireOwnerShop();
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse updateShop(ShopUpdateRequest request) {
        return shopService.updateOwnerShop(request);
    }

    @Transactional
    public ShopResponse setOpen(boolean open) {
        Shop shop = shopService.requireOwnerShop();
        if (shop.getApprovalStatus() == ShopApprovalStatus.SUSPENDED
                || shop.getApprovalStatus() == ShopApprovalStatus.REJECTED) {
            throw ApiException.forbidden("Your shop is not active. Contact the administrator.");
        }
        return shopService.updateOperationalStatus(shop.getId(), open);
    }

    @Transactional(readOnly = true)
    public List<InventoryResponse> inventory() {
        Shop shop = shopService.requireOwnerShop();
        return inventoryRepository.findAllByShop(shop.getId()).stream().map(this::toResponse).toList();
    }

    @Transactional
    public InventoryResponse addInventory(InventoryRequest request) {
        Shop shop = manageableShop();
        Product product = productRepository.findByIdAndActiveTrue(request.productId())
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        inventoryRepository.findByShopAndProduct(shop.getId(), product.getId()).ifPresent(existing -> {
            throw ApiException.conflict("INVENTORY_EXISTS",
                    "This product is already listed. Edit its price or stock instead.");
        });
        ShopInventory inventory = new ShopInventory();
        inventory.setShop(shop);
        inventory.setProduct(product);
        inventory.setPrice(request.price().setScale(2, RoundingMode.HALF_UP));
        inventory.setAvailableQuantity(request.availableQuantity());
        inventory.setActive(request.active() == null || request.active());
        inventoryRepository.save(inventory);
        return toResponse(inventory);
    }

    @Transactional
    public InventoryResponse updateInventory(Long id, InventoryRequest request) {
        Shop shop = manageableShop();
        ShopInventory inventory = ownedInventory(id, shop);
        if (!inventory.getProduct().getId().equals(request.productId())) {
            throw ApiException.badRequest("PRODUCT_IMMUTABLE",
                    "Create a new inventory record to list a different product.");
        }
        inventory.setPrice(request.price().setScale(2, RoundingMode.HALF_UP));
        inventory.setAvailableQuantity(request.availableQuantity());
        if (request.active() != null) {
            inventory.setActive(request.active());
        }
        inventoryRepository.save(inventory);
        return toResponse(inventory);
    }

    @Transactional
    public void removeInventory(Long id) {
        Shop shop = manageableShop();
        ShopInventory inventory = ownedInventory(id, shop);
        inventory.setActive(false);
        inventory.setAvailableQuantity(0);
        inventoryRepository.save(inventory);
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> productsNotListed() {
        Shop shop = shopService.requireOwnerShop();
        Set<Long> listed = new HashSet<>();
        for (ShopInventory inventory : inventoryRepository.findAllByShop(shop.getId())) {
            listed.add(inventory.getProduct().getId());
        }
        var availability = catalogService.availability();
        return productRepository.findAllByActiveTrueOrderByNameAsc().stream()
                .filter(product -> !listed.contains(product.getId()))
                .map(product -> CatalogMapper.toProduct(product, availability))
                .toList();
    }

    @Transactional
    public ProductResponse createProduct(ProductRequest request) {
        manageableShop();
        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        if (productRepository.existsByNameIgnoreCaseAndBrandIgnoreCase(
                request.name().trim(), request.brand() == null ? "" : request.brand().trim())) {
            throw ApiException.conflict("PRODUCT_EXISTS",
                    "A product with this name and brand already exists. Add it to your inventory instead.");
        }
        Product product = new Product();
        product.setName(request.name().trim());
        product.setDescription(request.description());
        product.setBrand(request.brand());
        product.setCategory(category);
        product.setImageUrl(request.imageUrl());
        product.setUnit(request.unit().trim());
        product.setActive(true);
        productRepository.save(product);
        return CatalogMapper.toProduct(product, catalogService.availability());
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> orders(OrderStatus status) {
        Shop shop = shopService.requireOwnerShop();
        return orderService.shopOrders(shop.getId(), status);
    }

    @Transactional
    public OrderResponse updateOrderStatus(Long orderId, UpdateOrderStatusRequest request) {
        Shop shop = shopService.requireOwnerShop();
        return orderService.updateStatusByOwner(orderId, request, shop);
    }

    @Transactional(readOnly = true)
    public com.puranabazaar.shopowner.dto.SalesHistoryResponse sales() {
        Shop shop = shopService.requireOwnerShop();
        List<OrderResponse> delivered = orderService.shopOrders(shop.getId(), OrderStatus.DELIVERED);
        BigDecimal total = orderRepository.totalDeliveredSalesForShop(shop.getId())
                .setScale(2, RoundingMode.HALF_UP);
        return new com.puranabazaar.shopowner.dto.SalesHistoryResponse(
                shop.getId(), shop.getName(), total, delivered.size(), delivered);
    }

    private Shop manageableShop() {
        Shop shop = shopService.requireOwnerShop();
        if (shop.getApprovalStatus() == ShopApprovalStatus.SUSPENDED
                || shop.getApprovalStatus() == ShopApprovalStatus.REJECTED) {
            throw ApiException.forbidden("Your shop is not active. Contact the administrator.");
        }
        return shop;
    }

    private ShopInventory ownedInventory(Long id, Shop shop) {
        ShopInventory inventory = inventoryRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("INVENTORY_NOT_FOUND", "Inventory item not found."));
        if (!inventory.getShop().getId().equals(shop.getId())) {
            throw ApiException.forbidden("You can only manage inventory for your own shop.");
        }
        return inventory;
    }

    private InventoryResponse toResponse(ShopInventory inventory) {
        Product product = inventory.getProduct();
        return new InventoryResponse(inventory.getId(), product.getId(), product.getName(), product.getBrand(),
                product.getUnit(), product.getImageUrl(), product.getCategory().getId(),
                product.getCategory().getName(), inventory.getPrice(), inventory.getAvailableQuantity(),
                inventory.isActive(), inventory.getUpdatedAt());
    }
}
