package com.puranabazaar.shopowner;

import com.puranabazaar.catalog.dto.ProductRequest;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.inventory.dto.InventoryRequest;
import com.puranabazaar.inventory.dto.InventoryResponse;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.order.dto.UpdateOrderStatusRequest;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.ShopService;
import com.puranabazaar.shop.dto.ShopResponse;
import com.puranabazaar.shop.dto.ShopUpdateRequest;
import com.puranabazaar.shopowner.dto.OwnerDashboardResponse;
import com.puranabazaar.shopowner.dto.SalesHistoryResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/shop-owner")
@PreAuthorize("hasRole('SHOP_OWNER')")
public class ShopOwnerController {

    public record ShopOpenRequest(boolean open) {
    }

    private final ShopOwnerService shopOwnerService;

    public ShopOwnerController(ShopOwnerService shopOwnerService) {
        this.shopOwnerService = shopOwnerService;
    }

    @GetMapping("/dashboard")
    public OwnerDashboardResponse dashboard() {
        return shopOwnerService.dashboard();
    }

    @GetMapping("/shop")
    public ShopResponse shop() {
        return shopOwnerService.shopProfile();
    }

    @PutMapping("/shop")
    public ShopResponse updateShop(@Valid @RequestBody ShopUpdateRequest request) {
        return shopOwnerService.updateShop(request);
    }

    @PutMapping("/shop/open")
    public ShopResponse setOpen(@RequestBody ShopOpenRequest request) {
        return shopOwnerService.setOpen(request.open());
    }

    @GetMapping("/inventory")
    public List<InventoryResponse> inventory() {
        return shopOwnerService.inventory();
    }

    @PostMapping("/inventory")
    public ResponseEntity<InventoryResponse> addInventory(@Valid @RequestBody InventoryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(shopOwnerService.addInventory(request));
    }

    @PutMapping("/inventory/{id}")
    public InventoryResponse updateInventory(@PathVariable Long id,
                                             @Valid @RequestBody InventoryRequest request) {
        return shopOwnerService.updateInventory(id, request);
    }

    @DeleteMapping("/inventory/{id}")
    public ResponseEntity<Void> removeInventory(@PathVariable Long id) {
        shopOwnerService.removeInventory(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/products/available")
    public List<ProductResponse> availableProducts() {
        return shopOwnerService.productsNotListed();
    }

    @PostMapping("/products")
    public ResponseEntity<ProductResponse> createProduct(@Valid @RequestBody ProductRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(shopOwnerService.createProduct(request));
    }

    @GetMapping("/orders")
    public List<OrderResponse> orders(@RequestParam(required = false) OrderStatus status) {
        return shopOwnerService.orders(status);
    }

    @PutMapping("/orders/{id}/status")
    public OrderResponse updateOrderStatus(@PathVariable Long id,
                                           @Valid @RequestBody UpdateOrderStatusRequest request) {
        return shopOwnerService.updateOrderStatus(id, request);
    }

    @GetMapping("/sales")
    public SalesHistoryResponse sales() {
        return shopOwnerService.sales();
    }
}
