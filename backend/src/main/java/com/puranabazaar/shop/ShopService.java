package com.puranabazaar.shop;

import com.puranabazaar.catalog.CatalogMapper;
import com.puranabazaar.catalog.CatalogService;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.inventory.dto.InventoryResponse;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.dto.ShopResponse;
import com.puranabazaar.shop.dto.ShopUpdateRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.Map;

@Service
public class ShopService {

    private final ShopRepository shopRepository;
    private final ShopInventoryRepository inventoryRepository;
    private final ShopMapper shopMapper;

    public ShopService(ShopRepository shopRepository, ShopInventoryRepository inventoryRepository,
                       ShopMapper shopMapper) {
        this.shopRepository = shopRepository;
        this.inventoryRepository = inventoryRepository;
        this.shopMapper = shopMapper;
    }

    @Transactional(readOnly = true)
    public List<ShopResponse> listApproved(String query, String category,
                                           Double latitude, Double longitude,
                                           boolean onlyOpen, boolean sortByDistance) {
        String normalizedQuery = normalize(query);
        List<Shop> shops = normalizedQuery == null
                ? shopRepository.findApprovedAndActive()
                : shopRepository.searchApproved(normalizedQuery);
        if (category != null && !category.isBlank()) {
            shops = shops.stream()
                    .filter(shop -> category.equalsIgnoreCase(shop.getShopCategory()))
                    .toList();
        }
        List<ShopResponse> responses = shops.stream()
                .map(shop -> shopMapper.toResponse(shop, latitude, longitude))
                .filter(shop -> !onlyOpen || shop.openNow())
                .collect(java.util.stream.Collectors.toCollection(java.util.ArrayList::new));
        if (sortByDistance && latitude != null && longitude != null) {
            responses.sort(Comparator.comparing(ShopResponse::distanceKm,
                    Comparator.nullsLast(Comparator.naturalOrder())));
        } else {
            responses.sort(Comparator.comparing(ShopResponse::name));
        }
        return responses;
    }

    @Transactional(readOnly = true)
    public List<ShopResponse> nearby(double latitude, double longitude, int limit) {
        return shopRepository.findApprovedAndActive().stream()
                .map(shop -> shopMapper.toResponse(shop, latitude, longitude))
                .filter(ShopResponse::deliverable)
                .filter(ShopResponse::deliveryAvailable)
                .sorted(Comparator.comparing(ShopResponse::distanceKm))
                .limit(Math.min(Math.max(limit, 1), 50))
                .toList();
    }

    @Transactional(readOnly = true)
    public ShopResponse getApproved(Long id, Double latitude, Double longitude) {
        Shop shop = shopRepository.findById(id)
                .filter(s -> s.getApprovalStatus() == ShopApprovalStatus.APPROVED
                        && s.getOperationalStatus() == ShopOperationalStatus.ACTIVE)
                .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND", "Shop not found."));
        return shopMapper.toResponse(shop, latitude, longitude);
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> shopProducts(Long shopId, Double latitude, Double longitude) {
        getApproved(shopId, latitude, longitude);
        return inventoryRepository.findActiveByShop(shopId).stream()
                .map(this::toProductWithShopPrice)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<InventoryResponse> shopInventory(Long shopId) {
        getApproved(shopId, null, null);
        return inventoryRepository.findActiveByShop(shopId).stream()
                .map(this::toInventoryResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> shopCategories(Long shopId) {
        getApproved(shopId, null, null);
        return inventoryRepository.findActiveByShop(shopId).stream()
                .map(ShopInventory::getProduct)
                .map(Product::getCategory)
                .distinct()
                .map(CatalogMapper::toCategory)
                .toList();
    }

    public ProductResponse toProductWithShopPrice(ShopInventory inventory) {
        return CatalogMapper.toProduct(inventory.getProduct(), inventory.getPrice(), 1,
                inventory.getAvailableQuantity());
    }

    private InventoryResponse toInventoryResponse(ShopInventory inventory) {
        Product product = inventory.getProduct();
        return new InventoryResponse(inventory.getId(), product.getId(), product.getName(), product.getBrand(),
                product.getUnit(), product.getImageUrl(), product.getCategory().getId(),
                product.getCategory().getName(), inventory.getPrice(), inventory.getAvailableQuantity(),
                inventory.isActive(), inventory.getUpdatedAt());
    }

    @Transactional(readOnly = true)
    public Shop requireOwnerShop() {
        return shopRepository.findFirstByOwnerId(CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND",
                        "No shop is linked to this owner account."));
    }

    @Transactional
    public ShopResponse updateOwnerShop(ShopUpdateRequest request) {
        Shop shop = requireOwnerShop();
        if (shop.getApprovalStatus() == ShopApprovalStatus.SUSPENDED
                || shop.getApprovalStatus() == ShopApprovalStatus.REJECTED) {
            throw ApiException.forbidden("Your shop is not active. Contact the administrator.");
        }
        if (request.name() != null && !request.name().isBlank()) shop.setName(request.name().trim());
        if (request.description() != null) shop.setDescription(request.description());
        if (request.address() != null && !request.address().isBlank()) shop.setAddress(request.address().trim());
        if (request.latitude() != null) shop.setLatitude(request.latitude());
        if (request.longitude() != null) shop.setLongitude(request.longitude());
        if (request.openingTime() != null) shop.setOpeningTime(request.openingTime());
        if (request.closingTime() != null) shop.setClosingTime(request.closingTime());
        if (request.deliveryRadius() != null) shop.setDeliveryRadius(request.deliveryRadius());
        if (request.deliveryAvailable() != null) shop.setDeliveryAvailable(request.deliveryAvailable());
        if (request.estimatedDeliveryMinutes() != null) shop.setEstimatedDeliveryMinutes(request.estimatedDeliveryMinutes());
        if (request.shopCategory() != null) shop.setShopCategory(request.shopCategory());
        if (request.imageUrl() != null) shop.setImageUrl(request.imageUrl());
        if (request.phone() != null) shop.setPhone(request.phone());
        shopRepository.save(shop);
        return shopMapper.toResponse(shop, null, null);
    }

    @Transactional
    public ShopResponse updateOperationalStatus(Long shopId, boolean active) {
        Shop shop = requireOwnerShop();
        if (!shop.getId().equals(shopId)) {
            throw ApiException.forbidden("You can only manage your own shop.");
        }
        shop.setOperationalStatus(active ? ShopOperationalStatus.ACTIVE : ShopOperationalStatus.TEMPORARILY_CLOSED);
        shopRepository.save(shop);
        return shopMapper.toResponse(shop, null, null);
    }

    public Map<Long, CatalogService.Availability> emptyAvailability() {
        return Map.of();
    }

    private String normalize(String query) {
        return query == null || query.isBlank() ? null : query.trim();
    }
}
