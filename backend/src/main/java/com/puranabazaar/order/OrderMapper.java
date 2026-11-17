package com.puranabazaar.order;

import com.puranabazaar.order.dto.OrderItemResponse;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.payment.Payment;
import com.puranabazaar.payment.PaymentRepository;
import com.puranabazaar.shop.ShopMapper;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class OrderMapper {

    private final ShopMapper shopMapper;
    private final PaymentRepository paymentRepository;

    public OrderMapper(ShopMapper shopMapper, PaymentRepository paymentRepository) {
        this.shopMapper = shopMapper;
        this.paymentRepository = paymentRepository;
    }

    public OrderResponse toResponse(ShopOrder order) {
        Payment payment = order.getId() == null
                ? null
                : paymentRepository.findByOrderId(order.getId()).orElse(null);
        List<OrderItemResponse> items = order.getItems().stream()
                .map(item -> new OrderItemResponse(item.getId(), item.getProduct().getId(),
                        item.getProductNameSnapshot(), item.getBrandSnapshot(), item.getUnitSnapshot(),
                        item.getImageUrlSnapshot(), item.getPriceSnapshot(), item.getQuantity(),
                        item.getTotalPrice()))
                .toList();
        boolean canRetry = order.getPaymentMethod() == PaymentMethod.ONLINE
                && (order.getPaymentStatus() == PaymentStatus.PENDING
                    || order.getPaymentStatus() == PaymentStatus.FAILED)
                && (order.getOrderStatus() == OrderStatus.PAYMENT_PENDING
                    || order.getOrderStatus() == OrderStatus.PAYMENT_FAILED);
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
                order.getUpdatedAt(),
                payment == null ? null : payment.getPaymentReference(),
                payment == null ? null : payment.getGateway(),
                canRetry
        );
    }

    public static boolean isCustomerCancellable(OrderStatus status) {
        return status == OrderStatus.PENDING || status == OrderStatus.ACCEPTED
                || status == OrderStatus.PREPARING || status == OrderStatus.PAYMENT_PENDING
                || status == OrderStatus.PAYMENT_FAILED;
    }
}
