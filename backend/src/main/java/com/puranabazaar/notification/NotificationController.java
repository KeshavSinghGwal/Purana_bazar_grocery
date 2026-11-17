package com.puranabazaar.notification;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
@PreAuthorize("isAuthenticated()")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public List<NotificationResponse> list(@RequestParam(defaultValue = "false") boolean unreadOnly) {
        return notificationService.list(unreadOnly);
    }

    @GetMapping("/unread-count")
    public Map<String, Object> unreadCount() {
        return Map.of(
                "count", notificationService.unreadCount(),
                "pushEnabled", notificationService.isPushAvailable());
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long id) {
        notificationService.markRead(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/read-all")
    public Map<String, Object> markAllRead() {
        return Map.of("updated", notificationService.markAllRead());
    }

    @PostMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registerDevice(@Valid @RequestBody DeviceRegistrationRequest request) {
        notificationService.registerDevice(request.token(), request.platform());
    }

    @DeleteMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeDevice(@RequestParam String token) {
        notificationService.removeDevice(token);
    }
}
