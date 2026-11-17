package com.puranabazaar.notification;

import java.time.Instant;

public record NotificationResponse(
        Long id,
        String title,
        String body,
        String type,
        Long orderId,
        String orderNumber,
        boolean read,
        Instant createdAt
) {
    public static NotificationResponse from(AppNotification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getTitle(),
                notification.getBody(),
                notification.getType(),
                notification.getOrderId(),
                notification.getOrderNumber(),
                notification.isRead(),
                notification.getCreatedAt());
    }
}
