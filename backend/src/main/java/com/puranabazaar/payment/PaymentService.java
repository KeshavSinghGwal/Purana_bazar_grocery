package com.puranabazaar.payment;

import com.puranabazaar.common.ApiException;
import com.puranabazaar.notification.NotificationService;
import com.puranabazaar.order.*;
import com.puranabazaar.order.dto.OrderResponse;
import com.puranabazaar.payment.dto.PaymentSessionResponse;
import com.puranabazaar.payment.dto.PaymentStatusResponse;
import com.puranabazaar.payment.dto.VerifyPaymentRequest;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.user.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);

    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final RazorpayClient razorpay;
    private final NotificationService notificationService;
    private final OrderMapper orderMapper;
    private final ObjectMapper objectMapper;

    public PaymentService(OrderRepository orderRepository, PaymentRepository paymentRepository,
                          RazorpayClient razorpay, NotificationService notificationService,
                          OrderMapper orderMapper, ObjectMapper objectMapper) {
        this.orderRepository = orderRepository;
        this.paymentRepository = paymentRepository;
        this.razorpay = razorpay;
        this.notificationService = notificationService;
        this.orderMapper = orderMapper;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public PaymentSessionResponse createSession(Long orderId) {
        ShopOrder order = customerOrder(orderId);
        onlinPaymentPreconditions(order);
        if (!razorpay.isAvailable()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ONLINE_PAYMENT_NOT_CONFIGURED",
                    "Online payments are not configured yet. Please choose Cash on Delivery.");
        }

        Payment payment = paymentRepository.findByOrderId(order.getId()).orElseGet(() -> {
            Payment created = new Payment();
            created.setOrder(order);
            created.setPaymentMethod(PaymentMethod.ONLINE);
            created.setAmount(order.getTotalAmount());
            return created;
        });
        if (payment.getPaymentStatus() == PaymentStatus.PAID) {
            throw ApiException.conflict("PAYMENT_ALREADY_COMPLETED", "This order has already been paid.");
        }

        Map<String, String> notes = new LinkedHashMap<>();
        notes.put("orderId", String.valueOf(order.getId()));
        notes.put("orderNumber", order.getOrderNumber());
        notes.put("customerId", String.valueOf(order.getCustomer().getId()));

        Map<String, Object> gatewayOrder = razorpay.createOrder(
                order.getTotalAmount(), order.getOrderNumber(), notes);
        String gatewayOrderId = String.valueOf(gatewayOrder.get("id"));

        payment.setOrder(order);
        payment.setPaymentMethod(PaymentMethod.ONLINE);
        payment.setAmount(order.getTotalAmount());
        payment.setGateway("RAZORPAY");
        payment.setGatewayOrderId(gatewayOrderId);
        payment.setPaymentStatus(PaymentStatus.PENDING);
        payment.setFailureReason(null);
        payment.setUpdatedAt(Instant.now());
        paymentRepository.save(payment);

        User customer = order.getCustomer();
        return new PaymentSessionResponse(
                order.getId(),
                order.getOrderNumber(),
                "RAZORPAY",
                gatewayOrderId,
                razorpay.publicKeyId(),
                RazorpayClient.toPaise(order.getTotalAmount()),
                order.getTotalAmount(),
                "INR",
                razorpay.isMock(),
                customer.getName(),
                customer.getEmail(),
                customer.getPhone(),
                "Purana Bazaar order " + order.getOrderNumber(),
                "#0c831f"
        );
    }

    @Transactional
    public OrderResponse verify(VerifyPaymentRequest request) {
        ShopOrder order = customerOrder(request.orderId());
        Payment payment = paymentRepository.findByOrderId(order.getId())
                .orElseThrow(() -> ApiException.conflict("PAYMENT_NOT_FOUND",
                        "No payment was started for this order."));
        if (payment.getPaymentStatus() == PaymentStatus.PAID) {
            return orderMapper.toResponse(order);
        }
        if (payment.getGatewayOrderId() == null
                || !payment.getGatewayOrderId().equals(request.razorpayOrderId())) {
            throw ApiException.conflict("PAYMENT_MISMATCH",
                    "This payment does not belong to the order. Please try again.");
        }
        if (!razorpay.verifyPaymentSignature(request.razorpayOrderId(),
                request.razorpayPaymentId(), request.razorpaySignature())) {
            throw ApiException.conflict("PAYMENT_VERIFICATION_FAILED",
                    "We could not verify this payment. If money was deducted, please contact support.");
        }
        if (razorpay.isConfigured()) {
            confirmCapturedPayment(request.razorpayPaymentId());
        }
        markPaid(order, payment, request.razorpayPaymentId(), request.razorpaySignature());
        return orderMapper.toResponse(order);
    }

    @Transactional(readOnly = true)
    public PaymentStatusResponse status(Long orderId) {
        ShopOrder order = customerOrder(orderId);
        Payment payment = paymentRepository.findByOrderId(order.getId()).orElse(null);
        return new PaymentStatusResponse(
                order.getId(),
                order.getOrderNumber(),
                order.getPaymentMethod().name(),
                order.getPaymentStatus().name(),
                order.getOrderStatus().name(),
                payment == null ? null : payment.getGateway(),
                payment == null ? null : payment.getGatewayOrderId(),
                payment == null ? null : payment.getGatewayPaymentId(),
                payment == null ? null : payment.getPaymentReference(),
                order.getTotalAmount(),
                orderMapper.toResponse(order).canRetryPayment()
        );
    }

    @Transactional
    public void handleWebhook(String payload, String signature) {
        if (!razorpay.hasWebhookSecret()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "WEBHOOK_NOT_CONFIGURED",
                    "Razorpay webhooks are not configured.");
        }
        if (!razorpay.verifyWebhookSignature(payload, signature)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_WEBHOOK_SIGNATURE",
                    "Invalid Razorpay webhook signature.");
        }
        JsonNode root;
        try {
            root = objectMapper.readTree(payload);
        } catch (Exception ex) {
            throw ApiException.badRequest("INVALID_WEBHOOK", "The webhook payload is not valid JSON.");
        }
        String event = root.path("event").asText("");
        JsonNode paymentNode = root.path("payload").path("payment").path("entity");
        String gatewayOrderId = paymentNode.path("order_id").asText("");
        String gatewayPaymentId = paymentNode.path("id").asText("");

        switch (event) {
            case "payment.captured", "order.paid" -> {
                Payment payment = paymentRepository.findByGatewayOrderId(gatewayOrderId).orElse(null);
                if (payment == null) {
                    log.warn("Razorpay webhook {} for unknown order {}", event, gatewayOrderId);
                    return;
                }
                if (payment.getPaymentStatus() == PaymentStatus.PAID) {
                    return;
                }
                ShopOrder order = payment.getOrder();
                if (gatewayPaymentId.isBlank()) {
                    gatewayPaymentId = paymentNode.path("id").asText("");
                }
                markPaid(order, payment, gatewayPaymentId, null);
            }
            case "payment.failed" -> {
                Payment payment = paymentRepository.findByGatewayOrderId(gatewayOrderId).orElse(null);
                if (payment == null) {
                    return;
                }
                String reason = paymentNode.path("error_description").asText("The payment failed.");
                payment.setPaymentStatus(PaymentStatus.FAILED);
                payment.setFailureReason(trim(reason, 300));
                payment.setUpdatedAt(Instant.now());
                paymentRepository.save(payment);
                ShopOrder order = payment.getOrder();
                order.setPaymentStatus(PaymentStatus.FAILED);
                orderRepository.save(order);
                notificationService.notifyUser(order.getCustomer(), "Payment failed",
                        "Payment for order " + order.getOrderNumber() + " did not go through. "
                                + "You can retry the payment from the order screen.",
                        "PAYMENT", order.getId(), order.getOrderNumber());
            }
            case "refund.processed", "refund.created" -> {
                JsonNode refundNode = root.path("payload").path("refund").path("entity");
                String refundedPaymentId = refundNode.path("payment_id").asText("");
                Payment payment = paymentRepository.findByGatewayPaymentId(refundedPaymentId)
                        .or(() -> paymentRepository.findByGatewayOrderId(gatewayOrderId))
                        .orElse(null);
                if (payment != null) {
                    payment.setPaymentStatus(PaymentStatus.REFUNDED);
                    payment.setRefundId(refundNode.path("id").asText(""));
                    payment.setRefundedAt(Instant.now());
                    payment.setUpdatedAt(Instant.now());
                    paymentRepository.save(payment);
                }
            }
            default -> log.debug("Ignoring Razorpay webhook event {}", event);
        }
    }

    /** Marks a cash-on-delivery order as collected. */
    @Transactional
    public void markCodPaid(ShopOrder order) {
        Payment payment = paymentRepository.findByOrderId(order.getId()).orElseGet(() -> {
            Payment created = new Payment();
            created.setOrder(order);
            created.setPaymentMethod(order.getPaymentMethod());
            created.setAmount(order.getTotalAmount());
            return created;
        });
        payment.setPaymentStatus(PaymentStatus.PAID);
        payment.setGateway("COD");
        payment.setPaymentReference("COD-" + order.getOrderNumber());
        payment.setPaidAt(Instant.now());
        payment.setUpdatedAt(Instant.now());
        paymentRepository.save(payment);
        order.setPaymentStatus(PaymentStatus.PAID);
    }

    /**
     * Refunds an online payment when an order is cancelled. Refunds are
     * best-effort: a gateway failure is logged and the order still cancels so
     * the customer is never stuck.
     */
    @Transactional
    public void refundIfPaid(ShopOrder order, String reason) {
        if (order.getPaymentMethod() != PaymentMethod.ONLINE) {
            return;
        }
        Payment payment = paymentRepository.findByOrderId(order.getId()).orElse(null);
        if (payment == null || payment.getPaymentStatus() != PaymentStatus.PAID) {
            return;
        }
        try {
            if (razorpay.isMockEnabled()) {
                payment.setRefundId("rfnd_mock_" + UUID.randomUUID().toString().substring(0, 8));
            } else if (razorpay.isConfigured() && payment.getGatewayPaymentId() != null) {
                Map<String, Object> refund = razorpay.refund(
                        payment.getGatewayPaymentId(), payment.getAmount(), reason);
                payment.setRefundId(String.valueOf(refund.getOrDefault("id", "")));
            } else {
                return;
            }
            payment.setPaymentStatus(PaymentStatus.REFUNDED);
            payment.setRefundedAt(Instant.now());
            payment.setUpdatedAt(Instant.now());
            paymentRepository.save(payment);
            order.setPaymentStatus(PaymentStatus.REFUNDED);
            notificationService.notifyUser(order.getCustomer(), "Refund initiated",
                    "A refund of ₹" + payment.getAmount().setScale(0)
                            + " has been initiated for order " + order.getOrderNumber()
                            + ". It usually reaches your account in 5–7 working days.",
                    "PAYMENT", order.getId(), order.getOrderNumber());
        } catch (Exception ex) {
            log.warn("Refund for order {} could not be completed: {}", order.getOrderNumber(), ex.getMessage());
        }
    }

    @Transactional
    public void markPaymentExpired(ShopOrder order) {
        paymentRepository.findByOrderId(order.getId()).ifPresent(payment -> {
            payment.setPaymentStatus(PaymentStatus.FAILED);
            payment.setFailureReason("Payment was not completed in time.");
            payment.setUpdatedAt(Instant.now());
            paymentRepository.save(payment);
        });
    }

    private void markPaid(ShopOrder order, Payment payment, String gatewayPaymentId, String signature) {
        payment.setPaymentStatus(PaymentStatus.PAID);
        payment.setGateway("RAZORPAY");
        payment.setGatewayPaymentId(gatewayPaymentId);
        if (signature != null) {
            payment.setGatewaySignature(signature);
        }
        payment.setPaymentReference(gatewayPaymentId);
        payment.setPaidAt(Instant.now());
        payment.setFailureReason(null);
        payment.setUpdatedAt(Instant.now());
        paymentRepository.save(payment);

        boolean wasPendingPayment = order.getOrderStatus() == OrderStatus.PAYMENT_PENDING
                || order.getOrderStatus() == OrderStatus.PAYMENT_FAILED;
        order.setPaymentStatus(PaymentStatus.PAID);
        if (wasPendingPayment) {
            order.setOrderStatus(OrderStatus.PENDING);
        }
        orderRepository.save(order);

        notificationService.notifyUser(order.getCustomer(), "Payment successful ✅",
                "We received ₹" + order.getTotalAmount().setScale(0)
                        + " for order " + order.getOrderNumber() + ". The shop will confirm it shortly.",
                "PAYMENT", order.getId(), order.getOrderNumber());
        notificationService.notifyUser(order.getShop().getOwner(), "New paid order",
                "Order " + order.getOrderNumber() + " from " + order.getCustomer().getName()
                        + " is paid (₹" + order.getTotalAmount().setScale(0) + "). Please accept it.",
                "ORDER", order.getId(), order.getOrderNumber());
    }

    private void onlinPaymentPreconditions(ShopOrder order) {
        if (order.getPaymentMethod() != PaymentMethod.ONLINE) {
            throw ApiException.badRequest("NOT_AN_ONLINE_ORDER",
                    "This order is set to Cash on Delivery.");
        }
        if (order.getOrderStatus() == OrderStatus.CANCELLED
                || order.getOrderStatus() == OrderStatus.REJECTED
                || order.getOrderStatus() == OrderStatus.DELIVERED) {
            throw ApiException.conflict("ORDER_CLOSED", "This order can no longer be paid.");
        }
        if (order.getPaymentStatus() == PaymentStatus.PAID) {
            throw ApiException.conflict("PAYMENT_ALREADY_COMPLETED", "This order has already been paid.");
        }
    }

    private void confirmCapturedPayment(String paymentId) {
        try {
            Map<String, Object> gatewayPayment = razorpay.fetchPayment(paymentId);
            String status = lower(gatewayPayment.get("status"));
            if ("failed".equals(status)) {
                throw ApiException.conflict("PAYMENT_FAILED_AT_GATEWAY",
                        "Razorpay reported that this payment failed. Please try again.");
            }
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            // The signature already proves authenticity; a lookup outage should
            // not block a legitimately captured payment.
            log.warn("Could not fetch Razorpay payment {}: {}", paymentId, ex.getMessage());
        }
    }

    private ShopOrder customerOrder(Long orderId) {
        return orderRepository.findByIdAndCustomerId(orderId, CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("ORDER_NOT_FOUND", "Order not found."));
    }

    private static String lower(Object value) {
        return value == null ? "" : String.valueOf(value).trim().toLowerCase(Locale.ROOT);
    }

    private static String trim(String value, int max) {
        if (value == null || value.isBlank()) {
            return "The payment failed.";
        }
        String safe = value.trim();
        return safe.length() <= max ? safe : safe.substring(0, max);
    }
}
