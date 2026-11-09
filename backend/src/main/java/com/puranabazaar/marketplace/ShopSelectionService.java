package com.puranabazaar.marketplace;

import com.puranabazaar.cart.Cart;
import com.puranabazaar.cart.CartItem;
import com.puranabazaar.cart.CartRepository;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.common.DeliveryFeeCalculator;
import com.puranabazaar.common.GeoUtils;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.marketplace.dto.FindShopRequest;
import com.puranabazaar.marketplace.dto.ShopQuoteResponse;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.address.CustomerAddress;
import com.puranabazaar.address.CustomerAddressRepository;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.ShopMapper;
import com.puranabazaar.shop.ShopOperationalStatus;
import com.puranabazaar.shop.ShopRepository;
import com.puranabazaar.user.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.*;

@Service
public class ShopSelectionService {

    private static final String NO_SHOP_MESSAGE =
            "Sorry! No nearby shop currently has all the products in your cart.";

    private final ShopRepository shopRepository;
    private final ShopInventoryRepository inventoryRepository;
    private final ProductRepository productRepository;
    private final CustomerAddressRepository addressRepository;
    private final CartRepository cartRepository;
    private final ShopMapper shopMapper;
    private final DeliveryFeeCalculator feeCalculator;
    private final ZoneId zoneId;

    public ShopSelectionService(ShopRepository shopRepository, ShopInventoryRepository inventoryRepository,
                                ProductRepository productRepository, CustomerAddressRepository addressRepository,
                                CartRepository cartRepository, ShopMapper shopMapper,
                                DeliveryFeeCalculator feeCalculator,
                                @Value("${app.timezone:Asia/Kolkata}") String timezone) {
        this.shopRepository = shopRepository;
        this.inventoryRepository = inventoryRepository;
        this.productRepository = productRepository;
        this.addressRepository = addressRepository;
        this.cartRepository = cartRepository;
        this.shopMapper = shopMapper;
        this.feeCalculator = feeCalculator;
        this.zoneId = ZoneId.of(timezone);
    }

    public record ProductLine(Long productId, int quantity) {
    }

    public record Location(double latitude, double longitude) {
    }

    @Transactional(readOnly = true)
    public ShopQuoteResponse findShopForProductChoice(User customer, FindShopRequest request) {
        Location location = resolveLocation(customer, request);
        List<ProductLine> lines = request.items() != null && !request.items().isEmpty()
                ? request.items().stream().map(line -> new ProductLine(line.productId(), line.quantity())).toList()
                : cartLines(customer.getId());
        return quoteNearestShop(location, lines);
    }

    @Transactional(readOnly = true)
    public ShopQuoteResponse validateCheckout(User customer, FindShopRequest request) {
        Location location = resolveLocation(customer, request);
        Cart cart = cartRepository.findByCustomerIdWithItems(customer.getId())
                .filter(c -> !c.getItems().isEmpty())
                .orElseThrow(() -> ApiException.badRequest("CART_EMPTY", "Your cart is empty."));
        if (cart.getShoppingMode() == com.puranabazaar.cart.ShoppingMode.SHOP_CHOICE) {
            if (cart.getSelectedShop() == null) {
                throw ApiException.conflict("SHOP_REQUIRED", "Select a shop before checkout.");
            }
            return quoteForSelectedShop(cart.getSelectedShop(), location, cartLines(cart));
        }
        return quoteNearestShop(location, cartLines(cart));
    }

    @Transactional(readOnly = true)
    public ShopQuoteResponse quoteForSelectedShop(Shop shop, Location location, List<ProductLine> lines) {
        if (lines.isEmpty()) {
            throw ApiException.badRequest("CART_EMPTY", "Your cart is empty.");
        }
        double distance = GeoUtils.distanceKm(location.latitude(), location.longitude(),
                shop.getLatitude(), shop.getLongitude());
        List<ShopQuoteResponse.ShopCandidate> candidate = List.of(new ShopQuoteResponse.ShopCandidate(
                shop.getId(), shop.getName(), GeoUtils.round2(distance), false, null));

        String invalidReason = shopUnavailableReason(shop, distance);
        if (invalidReason != null) {
            return unavailableQuote(lines, distance, List.of(new ShopQuoteResponse.ShopCandidate(
                    shop.getId(), shop.getName(), GeoUtils.round2(distance), false, invalidReason)));
        }
        InventoryCheck check = checkInventory(shop, lines);
        if (!check.complete) {
            return unavailableQuote(lines, distance, List.of(new ShopQuoteResponse.ShopCandidate(
                    shop.getId(), shop.getName(), GeoUtils.round2(distance), false,
                    missingReason(check))));
        }
        return buildFoundQuote(shop, distance, lines, check);
    }

    @Transactional(readOnly = true)
    public ShopQuoteResponse quoteNearestShop(Location location, List<ProductLine> lines) {
        if (lines.isEmpty()) {
            throw ApiException.badRequest("CART_EMPTY", "Your cart is empty.");
        }
        Map<Long, Product> products = loadProducts(lines);
        LocalTime now = LocalTime.now(zoneId);

        record ShopDistance(Shop shop, double distance) {
        }

        List<ShopDistance> approvedShops = shopRepository.findApprovedAndActive().stream()
                .map(shop -> new ShopDistance(shop, GeoUtils.distanceKm(
                        location.latitude(), location.longitude(), shop.getLatitude(), shop.getLongitude())))
                .sorted(Comparator.comparingDouble(ShopDistance::distance))
                .toList();

        List<ShopQuoteResponse.ShopCandidate> considered = new ArrayList<>();
        List<ShopDistance> reachable = new ArrayList<>();
        for (ShopDistance sd : approvedShops) {
            String reason = null;
            if (!sd.shop.isDeliveryAvailable()) {
                reason = "Shop does not offer delivery";
            } else if (!sd.shop.isOpenAt(now)) {
                reason = "Shop is currently closed";
            } else if (sd.distance > sd.shop.getDeliveryRadius()) {
                reason = "Outside delivery radius (" + sd.shop.getDeliveryRadius() + " km)";
            }
            if (reason == null) {
                reachable.add(sd);
            } else if (considered.size() < 10) {
                considered.add(new ShopQuoteResponse.ShopCandidate(sd.shop.getId(), sd.shop.getName(),
                        GeoUtils.round2(sd.distance), false, reason));
            }
        }

        List<ShopDistance> eligible = new ArrayList<>();
        Map<Long, InventoryCheck> checks = new HashMap<>();
        for (ShopDistance sd : reachable) {
            InventoryCheck check = checkInventory(sd.shop, lines);
            checks.put(sd.shop.getId(), check);
            if (check.complete) {
                eligible.add(sd);
            }
            if (considered.size() < 10) {
                considered.add(new ShopQuoteResponse.ShopCandidate(sd.shop.getId(), sd.shop.getName(),
                        GeoUtils.round2(sd.distance), check.complete,
                        check.complete ? null : missingReason(check)));
            }
        }

        if (eligible.isEmpty()) {
            return unavailableQuote(lines, null, considered, products);
        }

        ShopDistance selected = eligible.get(0);
        return buildFoundQuote(selected.shop, selected.distance, lines, checks.get(selected.shop.getId()));
    }

    private InventoryCheck checkInventory(Shop shop, List<ProductLine> lines) {
        List<Long> productIds = lines.stream().map(ProductLine::productId).toList();
        Map<Long, ShopInventory> inventoryByProduct = new HashMap<>();
        for (ShopInventory inventory : inventoryRepository.findForShopAndProducts(shop.getId(), productIds)) {
            inventoryByProduct.put(inventory.getProduct().getId(), inventory);
        }
        List<MissingItem> missing = new ArrayList<>();
        Map<Long, ShopInventory> usable = new HashMap<>();
        BigDecimal subtotal = BigDecimal.ZERO;
        for (ProductLine line : lines) {
            ShopInventory inventory = inventoryByProduct.get(line.productId());
            if (inventory == null || !inventory.isActive()) {
                missing.add(new MissingItem(line.productId(), line.quantity(), 0));
                continue;
            }
            usable.put(line.productId(), inventory);
            if (inventory.getAvailableQuantity() < line.quantity()) {
                missing.add(new MissingItem(line.productId(), line.quantity(), inventory.getAvailableQuantity()));
                continue;
            }
            subtotal = subtotal.add(inventory.getPrice().multiply(BigDecimal.valueOf(line.quantity())));
        }
        return new InventoryCheck(missing.isEmpty(), missing, usable, subtotal.setScale(2, RoundingMode.HALF_UP));
    }

    private ShopQuoteResponse buildFoundQuote(Shop shop, double distance, List<ProductLine> lines,
                                              InventoryCheck check) {
        List<ShopQuoteResponse.QuoteLine> quoteItems = new ArrayList<>();
        for (ProductLine line : lines) {
            ShopInventory inventory = check.inventory.get(line.productId());
            Product product = inventory.getProduct();
            BigDecimal lineTotal = inventory.getPrice().multiply(BigDecimal.valueOf(line.quantity()))
                    .setScale(2, RoundingMode.HALF_UP);
            quoteItems.add(new ShopQuoteResponse.QuoteLine(
                    product.getId(), product.getName(), product.getBrand(), product.getUnit(),
                    product.getImageUrl(), line.quantity(), inventory.getAvailableQuantity(),
                    inventory.getPrice(), lineTotal));
        }
        BigDecimal delivery = feeCalculator.feeFor(check.subtotal);
        return new ShopQuoteResponse(
                true,
                "Nearest shop that can fulfil your complete cart: " + shop.getName(),
                shopMapper.toResponse(shop, null, null),
                GeoUtils.round2(distance),
                quoteItems,
                check.subtotal,
                delivery,
                check.subtotal.add(delivery),
                List.of(),
                List.of()
        );
    }

    private ShopQuoteResponse unavailableQuote(List<ProductLine> lines, Double distance,
                                               List<ShopQuoteResponse.ShopCandidate> considered) {
        return unavailableQuote(lines, distance, considered, loadProducts(lines));
    }

    private ShopQuoteResponse unavailableQuote(List<ProductLine> lines, Double distance,
                                               List<ShopQuoteResponse.ShopCandidate> considered,
                                               Map<Long, Product> products) {
        List<Long> productIds = lines.stream().map(ProductLine::productId).toList();
        Map<Long, Integer> maxAvailable = new HashMap<>();
        for (ShopInventory inventory : inventoryRepository.findAvailableForProducts(productIds)) {
            maxAvailable.merge(inventory.getProduct().getId(), inventory.getAvailableQuantity(), Math::max);
        }
        List<ShopQuoteResponse.UnavailableProduct> unavailable = new ArrayList<>();
        for (ProductLine line : lines) {
            int max = maxAvailable.getOrDefault(line.productId(), 0);
            if (max < line.quantity()) {
                Product product = products.get(line.productId());
                unavailable.add(new ShopQuoteResponse.UnavailableProduct(line.productId(),
                        product == null ? "Product" : product.getName(), line.quantity(), max));
            }
        }
        return new ShopQuoteResponse(false, NO_SHOP_MESSAGE, null, distance, List.of(),
                BigDecimal.ZERO.setScale(2), BigDecimal.ZERO.setScale(2), BigDecimal.ZERO.setScale(2),
                unavailable, considered);
    }

    private String missingReason(InventoryCheck check) {
        if (check.missing.isEmpty()) {
            return null;
        }
        if (check.missing.size() == 1) {
            return "One item is unavailable in the requested quantity";
        }
        return check.missing.size() + " items are unavailable in the requested quantity";
    }

    private String shopUnavailableReason(Shop shop, double distance) {
        if (shop.getApprovalStatus() != ShopApprovalStatus.APPROVED) {
            return "Shop is not approved";
        }
        if (shop.getOperationalStatus() != ShopOperationalStatus.ACTIVE) {
            return "Shop is temporarily closed";
        }
        if (!shop.isDeliveryAvailable()) {
            return "Shop does not offer delivery";
        }
        if (!shop.isOpenAt(LocalTime.now(zoneId))) {
            return "Shop is currently closed";
        }
        if (distance > shop.getDeliveryRadius()) {
            return "Outside delivery radius (" + shop.getDeliveryRadius() + " km)";
        }
        return null;
    }

    public Location resolveLocation(User customer, FindShopRequest request) {
        if (request.addressId() != null) {
            CustomerAddress address = addressRepository.findByIdAndCustomerId(request.addressId(), customer.getId())
                    .orElseThrow(() -> ApiException.notFound("ADDRESS_NOT_FOUND", "Delivery address not found."));
            return new Location(address.getLatitude(), address.getLongitude());
        }
        if (request.latitude() != null && request.longitude() != null) {
            return new Location(request.latitude(), request.longitude());
        }
        return addressRepository.findFirstByCustomerIdAndDefaultAddressTrue(customer.getId())
                .map(address -> new Location(address.getLatitude(), address.getLongitude()))
                .orElseThrow(() -> ApiException.badRequest("LOCATION_REQUIRED",
                        "Add a delivery address or share your location to continue."));
    }

    public List<ProductLine> cartLines(Long customerId) {
        Cart cart = cartRepository.findByCustomerIdWithItems(customerId)
                .orElseThrow(() -> ApiException.badRequest("CART_EMPTY", "Your cart is empty."));
        return cartLines(cart);
    }

    public List<ProductLine> cartLines(Cart cart) {
        List<ProductLine> lines = new ArrayList<>();
        for (CartItem item : cart.getItems()) {
            if (item.getProduct() != null) {
                lines.add(new ProductLine(item.getProduct().getId(), item.getQuantity()));
            }
        }
        if (lines.isEmpty()) {
            throw ApiException.badRequest("CART_EMPTY", "Your cart is empty.");
        }
        return lines;
    }

    private Map<Long, Product> loadProducts(List<ProductLine> lines) {
        Map<Long, Product> products = new HashMap<>();
        for (Product product : productRepository.findAllById(lines.stream().map(ProductLine::productId).toList())) {
            products.put(product.getId(), product);
        }
        for (ProductLine line : lines) {
            if (!products.containsKey(line.productId()) || !products.get(line.productId()).isActive()) {
                throw ApiException.notFound("PRODUCT_NOT_FOUND", "One of the products is no longer available.");
            }
        }
        return products;
    }

    private record MissingItem(Long productId, int requested, int available) {
    }

    private record InventoryCheck(boolean complete, List<MissingItem> missing,
                                  Map<Long, ShopInventory> inventory, BigDecimal subtotal) {
    }
}
