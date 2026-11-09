package com.puranabazaar.admin;

import com.puranabazaar.admin.dto.AdminCustomerResponse;
import com.puranabazaar.admin.dto.AdminDashboardResponse;
import com.puranabazaar.catalog.CatalogService;
import com.puranabazaar.catalog.dto.CategoryRequest;
import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductRequest;
import com.puranabazaar.catalog.dto.ProductResponse;
import com.puranabazaar.common.PageResponse;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.order.dto.CancelOrderRequest;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.dto.ShopRejectRequest;
import com.puranabazaar.shop.dto.ShopResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminService adminService;
    private final CatalogService catalogService;

    public AdminController(AdminService adminService, CatalogService catalogService) {
        this.adminService = adminService;
        this.catalogService = catalogService;
    }

    @GetMapping("/dashboard")
    public AdminDashboardResponse dashboard() {
        return adminService.dashboard();
    }

    @GetMapping("/shops")
    public List<ShopResponse> shops(@RequestParam(required = false) ShopApprovalStatus status) {
        return adminService.shops(status);
    }

    @GetMapping("/shops/pending")
    public List<ShopResponse> pendingShops() {
        return adminService.shops(ShopApprovalStatus.PENDING_APPROVAL);
    }

    @GetMapping("/shops/{id}")
    public ShopResponse shop(@PathVariable Long id) {
        return adminService.shop(id);
    }

    @PutMapping("/shops/{id}/approve")
    public ShopResponse approve(@PathVariable Long id) {
        return adminService.approve(id);
    }

    @PutMapping("/shops/{id}/reject")
    public ShopResponse reject(@PathVariable Long id, @Valid @RequestBody ShopRejectRequest request) {
        return adminService.reject(id, request.reason());
    }

    @PutMapping("/shops/{id}/suspend")
    public ShopResponse suspend(@PathVariable Long id, @Valid @RequestBody ShopRejectRequest request) {
        return adminService.suspend(id, request.reason());
    }

    @PutMapping("/shops/{id}/reactivate")
    public ShopResponse reactivate(@PathVariable Long id) {
        return adminService.reactivate(id);
    }

    @GetMapping("/customers")
    public List<AdminCustomerResponse> customers() {
        return adminService.customers();
    }

    @PutMapping("/customers/{id}/suspend")
    public AdminCustomerResponse suspendCustomer(@PathVariable Long id) {
        return adminService.setCustomerActive(id, false);
    }

    @PutMapping("/customers/{id}/reactivate")
    public AdminCustomerResponse reactivateCustomer(@PathVariable Long id) {
        return adminService.setCustomerActive(id, true);
    }

    @GetMapping("/orders")
    public List<OrderResponse> orders(@RequestParam(required = false) OrderStatus status,
                                      @RequestParam(required = false) Long shopId) {
        return adminService.orders(status, shopId);
    }

    @GetMapping("/orders/{id}")
    public OrderResponse order(@PathVariable Long id) {
        return adminService.order(id);
    }

    @PutMapping("/orders/{id}/cancel")
    public OrderResponse cancelOrder(@PathVariable Long id,
                                     @RequestBody(required = false) CancelOrderRequest request) {
        return adminService.cancelOrder(id, request == null ? null : request.reason());
    }

    @GetMapping("/categories")
    public List<CategoryResponse> categories() {
        return catalogService.listCategories(true);
    }

    @PostMapping("/categories")
    public ResponseEntity<CategoryResponse> createCategory(@Valid @RequestBody CategoryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(catalogService.createCategory(request));
    }

    @PutMapping("/categories/{id}")
    public CategoryResponse updateCategory(@PathVariable Long id,
                                           @Valid @RequestBody CategoryRequest request) {
        return catalogService.updateCategory(id, request);
    }

    @DeleteMapping("/categories/{id}")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long id) {
        catalogService.deactivateCategory(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/products")
    public PageResponse<ProductResponse> products(@RequestParam(required = false) String q,
                                                  @RequestParam(required = false) Long categoryId,
                                                  @RequestParam(defaultValue = "0") int page,
                                                  @RequestParam(defaultValue = "50") int size) {
        return catalogService.adminProducts(q, categoryId, page, size);
    }

    @PostMapping("/products")
    public ResponseEntity<ProductResponse> createProduct(@Valid @RequestBody ProductRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(catalogService.createProduct(request));
    }

    @PutMapping("/products/{id}")
    public ProductResponse updateProduct(@PathVariable Long id,
                                         @Valid @RequestBody ProductRequest request) {
        return catalogService.updateProduct(id, request);
    }

    @DeleteMapping("/products/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        catalogService.deactivateProduct(id);
        return ResponseEntity.noContent().build();
    }
}
