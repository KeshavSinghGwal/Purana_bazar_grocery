package com.puranabazaar.payment;

import com.puranabazaar.payment.dto.PaymentSessionResponse;
import com.puranabazaar.payment.dto.PaymentStatusResponse;
import com.puranabazaar.payment.dto.VerifyPaymentRequest;
import com.puranabazaar.order.dto.OrderResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/payments")
@PreAuthorize("hasRole('CUSTOMER')")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    public record CreateSessionRequest(@NotNull Long orderId) {
    }

    @PostMapping("/razorpay/order")
    public PaymentSessionResponse createSession(@Valid @RequestBody CreateSessionRequest request) {
        return paymentService.createSession(request.orderId());
    }

    @PostMapping("/razorpay/verify")
    public OrderResponse verify(@Valid @RequestBody VerifyPaymentRequest request) {
        return paymentService.verify(request);
    }

    @GetMapping("/orders/{orderId}")
    public PaymentStatusResponse status(@PathVariable Long orderId) {
        return paymentService.status(orderId);
    }

    @PostMapping("/razorpay/webhook")
    @PreAuthorize("permitAll()")
    public Map<String, String> webhook(@RequestBody String payload,
                                       @RequestHeader(value = "X-Razorpay-Signature", required = false)
                                       String signature) {
        paymentService.handleWebhook(payload, signature);
        return Map.of("status", "ok");
    }
}
