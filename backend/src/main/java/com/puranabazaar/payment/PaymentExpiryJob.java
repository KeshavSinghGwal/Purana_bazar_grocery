package com.puranabazaar.payment;

import com.puranabazaar.order.OrderService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PaymentExpiryJob {

    private static final Logger log = LoggerFactory.getLogger(PaymentExpiryJob.class);

    private final OrderService orderService;

    public PaymentExpiryJob(OrderService orderService) {
        this.orderService = orderService;
    }

    /** Releases stock reserved by online orders that were never paid. */
    @Scheduled(fixedDelayString = "${app.payment.expiry-scan-ms:300000}", initialDelay = 120000)
    public void expireUnpaidOrders() {
        try {
            int expired = orderService.expireUnpaidOnlineOrders();
            if (expired > 0) {
                log.info("Expired {} unpaid online order(s) and restored their stock.", expired);
            }
        } catch (Exception ex) {
            log.warn("Could not expire unpaid online orders: {}", ex.getMessage());
        }
    }
}
