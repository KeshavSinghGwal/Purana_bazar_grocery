package com.puranabazaar.delivery;

import com.puranabazaar.common.ApiException;
import com.puranabazaar.delivery.dto.DeliveryDashboardResponse;
import com.puranabazaar.notification.NotificationService;
import com.puranabazaar.order.*;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.order.dto.UpdateOrderStatusRequest;
import com.puranabazaar.payment.PaymentService;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.user.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
public class DeliveryService {

    private static final List<OrderStatus> ACTIVE_STATUSES =
            List.of(OrderStatus.READY_FOR_PICKUP, OrderStatus.OUT_FOR_DELIVERY);

    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
    private final OrderService orderService;
    private final NotificationService notificationService;

    public DeliveryService(OrderRepository orderRepository, PaymentService paymentService,
                           OrderService orderService, NotificationService notificationService) {
        this.orderRepository = orderRepository;
        this.paymentService = paymentService;
        this.orderService = orderService;
        this.notificationService = notificationService;
    }

    @Transactional(readOnly = true)
    public DeliveryDashboardResponse dashboard() {
        User partner = CurrentUser.require();
        List<OrderResponse> active = orderRepository
                .findByDeliveryPartnerIdOrderByCreatedAtDesc(partner.getId()).stream()
                .filter(order -> ACTIVE_STATUSES.contains(order.getOrderStatus()))
                .map(orderService::toResponse)
                .toList();
        return new DeliveryDashboardResponse(
                partner.getName(),
                orderRepository.findByOrderStatusAndDeliveryPartnerIsNullOrderByCreatedAtAsc(
                        OrderStatus.READY_FOR_PICKUP).size(),
                active.size(),
                orderRepository.countByDeliveryPartnerIdAndOrderStatus(
                        partner.getId(), OrderStatus.DELIVERED),
                orderRepository.totalDeliveryFeesForPartner(partner.getId()),
                active
        );
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> availableOrders() {
        return orderRepository
                .findByOrderStatusAndDeliveryPartnerIsNullOrderByCreatedAtAsc(OrderStatus.READY_FOR_PICKUP)
                .stream()
                .map(orderService::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> myOrders(OrderStatus status) {
        Long partnerId = CurrentUser.id();
        List<ShopOrder> orders = status == null
                ? orderRepository.findByDeliveryPartnerIdOrderByCreatedAtDesc(partnerId)
                : orderRepository.findByDeliveryPartnerIdAndOrderStatusOrderByCreatedAtDesc(partnerId, status);
        return orders.stream().map(orderService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse myOrder(Long orderId) {
        return toPartnerOrder(orderId);
    }

    @Transactional
    public OrderResponse accept(Long orderId) {
        User partner = CurrentUser.require();
        ShopOrder order = orderRepository.findByIdForUpdate(orderId)
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
        if (order.getDeliveryPartner() != null) {
            if (order.getDeliveryPartner().getId().equals(partner.getId())) {
                return orderService.toResponse(order);
            }
            throw ApiException.conflict("DELIVERY_ALREADY_ASSIGNED",
                    "Another delivery partner has already accepted this order.");
        }
        if (order.getOrderStatus() != OrderStatus.READY_FOR_PICKUP) {
            throw ApiException.conflict("ORDER_NOT_READY",
                    "This order is not ready for pickup yet.");
        }
        order.setDeliveryPartner(partner);
        order.setDeliveryAssignedAt(Instant.now());
        orderRepository.save(order);

        notificationService.notifyUser(order.getCustomer(), "Delivery partner assigned",
                partner.getName() + " will deliver order " + order.getOrderNumber()
                        + ". They will call you if needed.",
                "DELIVERY", order.getId(), order.getOrderNumber());
        notificationService.notifyUser(order.getShop().getOwner(), "Order assigned for delivery",
                partner.getName() + " accepted order " + order.getOrderNumber() + " for pickup.",
                "DELIVERY", order.getId(), order.getOrderNumber());
        return orderService.toResponse(order);
    }

    @Transactional
    public OrderResponse updateStatus(Long orderId, UpdateOrderStatusRequest request) {
        Long partnerId = CurrentUser.id();
        ShopOrder order = orderRepository.findByIdForUpdate(orderId)
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
        if (order.getDeliveryPartner() == null
                || !order.getDeliveryPartner().getId().equals(partnerId)) {
            throw ApiException.forbidden("You can only update deliveries assigned to you.");
        }
        OrderStatus target = request.status();
        if (target == order.getOrderStatus()) {
            return orderService.toResponse(order);
        }
        if (!isPartnerTransitionAllowed(order.getOrderStatus(), target)) {
            throw ApiException.conflict("INVALID_STATUS_TRANSITION",
                    "Cannot change order status from " + order.getOrderStatus() + " to " + target + ".");
        }
        if (target == OrderStatus.DELIVERED) {
            paymentService.markCodPaid(order);
        }
        order.setOrderStatus(target);
        orderRepository.save(order);

        if (target == OrderStatus.OUT_FOR_DELIVERY) {
            notificationService.notifyUser(order.getCustomer(), "Out for delivery 🛵",
                    order.getDeliveryPartner().getName() + " is on the way with order "
                            + order.getOrderNumber() + ".",
                    "DELIVERY", order.getId(), order.getOrderNumber());
        } else if (target == OrderStatus.DELIVERED) {
            notificationService.notifyUser(order.getCustomer(), "Delivered 🎉",
                    "Order " + order.getOrderNumber() + " has been delivered. Enjoy your groceries!",
                    "DELIVERY", order.getId(), order.getOrderNumber());
            notificationService.notifyUser(order.getShop().getOwner(), "Order delivered",
                    "Order " + order.getOrderNumber() + " was delivered successfully.",
                    "DELIVERY", order.getId(), order.getOrderNumber());
        }
        return orderService.toResponse(order);
    }

    private OrderResponse toPartnerOrder(Long orderId) {
        ShopOrder order = orderRepository.findByIdAndDeliveryPartnerId(orderId, CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND",
                        "Delivery order not found."));
        return orderService.toResponse(order);
    }

    private boolean isPartnerTransitionAllowed(OrderStatus current, OrderStatus target) {
        return switch (current) {
            case READY_FOR_PICKUP -> target == OrderStatus.OUT_FOR_DELIVERY;
            case OUT_FOR_DELIVERY -> target == OrderStatus.DELIVERED;
            default -> false;
        };
    }
}
