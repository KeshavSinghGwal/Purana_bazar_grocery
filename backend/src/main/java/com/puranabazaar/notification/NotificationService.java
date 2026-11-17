package com.puranabazaar.notification;

import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.user.Role;
import com.puranabazaar.user.User;
import com.puranabazaar.user.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final AppNotificationRepository notificationRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;
    private final PushDispatcher pushDispatcher;

    public NotificationService(AppNotificationRepository notificationRepository,
                               DeviceTokenRepository deviceTokenRepository,
                               UserRepository userRepository,
                               PushDispatcher pushDispatcher) {
        this.notificationRepository = notificationRepository;
        this.deviceTokenRepository = deviceTokenRepository;
        this.userRepository = userRepository;
        this.pushDispatcher = pushDispatcher;
    }

    /**
     * Persists an in-app notification and queues an FCM push. Runs in its own
     * transaction so a notification problem can never roll back an order.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyUser(User user, String title, String body, String type,
                           Long orderId, String orderNumber) {
        if (user == null || user.getId() == null) {
            return;
        }
        try {
            persistAndPush(user, title, body, type, orderId, orderNumber);
        } catch (Exception ex) {
            log.warn("Could not create a notification for user {}: {}", user.getId(), ex.getMessage());
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyRole(Role role, String title, String body, String type,
                           Long orderId, String orderNumber) {
        try {
            for (User user : userRepository.findAllByRoleOrderByCreatedAtDesc(role)) {
                if (!user.isActive()) {
                    continue;
                }
                try {
                    persistAndPush(user, title, body, type, orderId, orderNumber);
                } catch (Exception ex) {
                    log.debug("Notification skipped for user {}: {}", user.getId(), ex.getMessage());
                }
            }
        } catch (Exception ex) {
            log.warn("Could not broadcast a {} notification: {}", role, ex.getMessage());
        }
    }

    private void persistAndPush(User user, String title, String body, String type,
                                Long orderId, String orderNumber) {
        AppNotification notification = new AppNotification();
        notification.setUser(user);
        notification.setTitle(trim(title, 180));
        notification.setBody(trim(body, 600));
        notification.setType(type == null ? "GENERAL" : type);
        notification.setOrderId(orderId);
        notification.setOrderNumber(orderNumber);
        notificationRepository.save(notification);

        List<String> tokens = deviceTokenRepository.findByUserIdAndActiveTrue(user.getId()).stream()
                .map(DeviceToken::getToken)
                .toList();
        if (!tokens.isEmpty()) {
            Map<String, String> data = new LinkedHashMap<>();
            data.put("type", notification.getType());
            if (orderId != null) {
                data.put("orderId", String.valueOf(orderId));
            }
            if (orderNumber != null) {
                data.put("orderNumber", orderNumber);
            }
            pushDispatcher.dispatch(notification.getTitle(), notification.getBody(), data, tokens);
        }
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> list(boolean unreadOnly) {
        Long userId = CurrentUser.id();
        List<AppNotification> items = unreadOnly
                ? notificationRepository.findTop100ByUserIdAndReadFalseOrderByCreatedAtDesc(userId)
                : notificationRepository.findTop100ByUserIdOrderByCreatedAtDesc(userId);
        return items.stream().map(NotificationResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public long unreadCount() {
        return notificationRepository.countByUserIdAndReadFalse(CurrentUser.id());
    }

    @Transactional
    public void markRead(Long id) {
        AppNotification notification = notificationRepository
                .findByIdAndUserId(id, CurrentUser.id())
                .orElseThrow(() -> com.puranabazaar.common.ApiException.notFound(
                        "NOTIFICATION_NOT_FOUND", "Notification not found."));
        if (!notification.isRead()) {
            notification.setRead(true);
            notificationRepository.save(notification);
        }
    }

    @Transactional
    public int markAllRead() {
        return notificationRepository.markAllRead(CurrentUser.id());
    }

    @Transactional
    public void registerDevice(String token, String platform) {
        User user = CurrentUser.require();
        String cleanToken = token.trim();
        DeviceToken device = deviceTokenRepository.findByToken(cleanToken).orElseGet(DeviceToken::new);
        device.setUser(user);
        device.setToken(cleanToken);
        device.setPlatform(normalizePlatform(platform));
        device.setActive(true);
        device.setLastSeenAt(Instant.now());
        deviceTokenRepository.save(device);
    }

    @Transactional
    public void removeDevice(String token) {
        if (token != null && !token.isBlank()) {
            deviceTokenRepository.deactivateByToken(token.trim());
        }
    }

    @Transactional
    public void sendWelcome(User user) {
        runAfterCommit(() -> notifyUser(user, "Welcome to Purana Bazaar 👋",
                "Discover fresh groceries from trusted neighbourhood shops. Your orders and delivery updates will appear here.",
                "ACCOUNT", null, null));
    }

    /**
     * Registration happens in the same transaction that creates the user, so the
     * welcome notification must wait until the user row is committed.
     */
    public void runAfterCommit(Runnable action) {
        if (org.springframework.transaction.support.TransactionSynchronizationManager
                .isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager
                    .registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            action.run();
                        }
                    });
        } else {
            action.run();
        }
    }

    public boolean isPushAvailable() {
        return pushDispatcher.isAvailable();
    }

    private static String normalizePlatform(String platform) {
        if (platform == null || platform.isBlank()) {
            return "WEB";
        }
        return platform.trim().toUpperCase(java.util.Locale.ROOT);
    }

    private static String trim(String value, int max) {
        String safe = value == null || value.isBlank() ? "Update" : value.trim();
        return safe.length() <= max ? safe : safe.substring(0, max);
    }
}
