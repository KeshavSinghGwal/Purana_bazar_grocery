package com.puranabazaar.payment;

import com.puranabazaar.common.ApiException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Thin Razorpay REST client. The official SDK is deliberately not used so the
 * application only depends on Spring's HTTP client and the documented REST API.
 */
@Component
public class RazorpayClient {

    private static final Logger log = LoggerFactory.getLogger(RazorpayClient.class);
    private static final String BASE_URL = "https://api.razorpay.com/v1";

    private final String keyId;
    private final String keySecret;
    private final String webhookSecret;
    private final boolean mockEnabled;
    private final RestClient restClient;

    public RazorpayClient(@Value("${app.razorpay.key-id:}") String keyId,
                          @Value("${app.razorpay.key-secret:}") String keySecret,
                          @Value("${app.razorpay.webhook-secret:}") String webhookSecret,
                          @Value("${app.razorpay.mock-enabled:false}") boolean mockEnabled) {
        this.keyId = keyId == null ? "" : keyId.trim();
        this.keySecret = keySecret == null ? "" : keySecret.trim();
        this.webhookSecret = webhookSecret == null ? "" : webhookSecret.trim();
        this.mockEnabled = mockEnabled;
        String credentials = Base64.getEncoder().encodeToString(
                (this.keyId + ":" + this.keySecret).getBytes(StandardCharsets.UTF_8));
        this.restClient = RestClient.builder()
                .baseUrl(BASE_URL)
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Basic " + credentials)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    public boolean isConfigured() {
        return !keyId.isBlank() && !keySecret.isBlank();
    }

    /** Test mode used by local demos when real Razorpay keys are not configured. */
    public boolean isMockEnabled() {
        return !isConfigured() && mockEnabled;
    }

    public boolean isAvailable() {
        return isConfigured() || isMockEnabled();
    }

    public boolean isMock() {
        return isMockEnabled();
    }

    public String publicKeyId() {
        return isConfigured() ? keyId : "rzp_test_mock";
    }

    public boolean hasWebhookSecret() {
        return !webhookSecret.isBlank();
    }

    public static long toPaise(BigDecimal amount) {
        return amount.multiply(BigDecimal.valueOf(100))
                .setScale(0, RoundingMode.HALF_UP)
                .longValueExact();
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> createOrder(BigDecimal amount, String receipt, Map<String, String> notes) {
        long paise = toPaise(amount);
        if (isMockEnabled()) {
            Map<String, Object> mock = new LinkedHashMap<>();
            mock.put("id", "order_mock_" + UUID.randomUUID().toString().replace("-", "").substring(0, 14));
            mock.put("amount", paise);
            mock.put("currency", "INR");
            mock.put("receipt", receipt);
            mock.put("status", "created");
            return mock;
        }
        requireConfigured();
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("amount", paise);
        payload.put("currency", "INR");
        payload.put("receipt", receipt);
        payload.put("notes", notes == null ? Map.of() : notes);
        try {
            Map<String, Object> response = restClient.post()
                    .uri("/orders")
                    .body(payload)
                    .retrieve()
                    .body(Map.class);
            if (response == null || response.get("id") == null) {
                throw gatewayError("Razorpay did not return an order id.");
            }
            return response;
        } catch (RestClientException ex) {
            log.warn("Razorpay order creation failed: {}", ex.getMessage());
            throw gatewayError("Could not start the online payment. Please try again.");
        }
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> fetchPayment(String paymentId) {
        requireConfigured();
        try {
            Map<String, Object> response = restClient.get()
                    .uri("/payments/{id}", paymentId)
                    .retrieve()
                    .body(Map.class);
            return response == null ? Map.of() : response;
        } catch (RestClientException ex) {
            log.warn("Razorpay payment lookup failed for {}: {}", paymentId, ex.getMessage());
            throw gatewayError("Could not confirm the payment with Razorpay. Please try again.");
        }
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> refund(String paymentId, BigDecimal amount, String reason) {
        requireConfigured();
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("amount", toPaise(amount));
        payload.put("speed", "normal");
        payload.put("notes", Map.of("reason", reason == null ? "Order cancelled" : reason));
        try {
            Map<String, Object> response = restClient.post()
                    .uri("/payments/{id}/refund", paymentId)
                    .body(payload)
                    .retrieve()
                    .body(Map.class);
            return response == null ? Map.of() : response;
        } catch (RestClientException ex) {
            log.warn("Razorpay refund failed for {}: {}", paymentId, ex.getMessage());
            throw gatewayError("The payment could not be refunded automatically. Please contact support.");
        }
    }

    public boolean verifyPaymentSignature(String razorpayOrderId, String razorpayPaymentId,
                                          String razorpaySignature) {
        if (isMockEnabled()) {
            return "mock".equalsIgnoreCase(razorpaySignature);
        }
        requireConfigured();
        String expected = hmacHex(razorpayOrderId + "|" + razorpayPaymentId, keySecret);
        return constantTimeEquals(expected, razorpaySignature);
    }

    public boolean verifyWebhookSignature(String payload, String signature) {
        if (!hasWebhookSecret() || signature == null || signature.isBlank()) {
            return false;
        }
        String expected = hmacHex(payload, webhookSecret);
        return constantTimeEquals(expected, signature);
    }

    private void requireConfigured() {
        if (!isConfigured()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ONLINE_PAYMENT_NOT_CONFIGURED",
                    "Online payments are not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET, "
                            + "or enable RAZORPAY_MOCK_ENABLED for local testing.");
        }
    }

    private ApiException gatewayError(String message) {
        return new ApiException(HttpStatus.BAD_GATEWAY, "PAYMENT_GATEWAY_ERROR", message);
    }

    private static String hmacHex(String data, String secret) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] digest = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                hex.append(String.format(Locale.ROOT, "%02x", b));
            }
            return hex.toString();
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to compute the Razorpay signature.", ex);
        }
    }

    private static boolean constantTimeEquals(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                actual.getBytes(StandardCharsets.UTF_8));
    }
}
