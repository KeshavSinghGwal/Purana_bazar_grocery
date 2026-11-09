package com.puranabazaar.delivery;

import com.puranabazaar.delivery.dto.DeliveryDashboardResponse;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.order.dto.UpdateOrderStatusRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/delivery")
@PreAuthorize("hasRole('DELIVERY_PARTNER')")
public class DeliveryController {

    private final DeliveryService deliveryService;

    public DeliveryController(DeliveryService deliveryService) {
        this.deliveryService = deliveryService;
    }

    @GetMapping("/dashboard")
    public DeliveryDashboardResponse dashboard() {
        return deliveryService.dashboard();
    }

    @GetMapping("/available")
    public List<OrderResponse> available() {
        return deliveryService.availableOrders();
    }

    @GetMapping("/orders")
    public List<OrderResponse> orders(@RequestParam(required = false) OrderStatus status) {
        return deliveryService.myOrders(status);
    }

    @GetMapping("/orders/{id}")
    public OrderResponse order(@PathVariable Long id) {
        return deliveryService.myOrder(id);
    }

    @PutMapping("/orders/{id}/accept")
    public OrderResponse accept(@PathVariable Long id) {
        return deliveryService.accept(id);
    }

    @PutMapping("/orders/{id}/status")
    public OrderResponse updateStatus(@PathVariable Long id,
                                      @Valid @RequestBody UpdateOrderStatusRequest request) {
        return deliveryService.updateStatus(id, request);
    }
}
