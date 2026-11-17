package com.puranabazaar.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.SendResponse;
import com.google.firebase.messaging.WebpushConfig;
import com.google.firebase.messaging.WebpushNotification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * Sends Firebase Cloud Messaging pushes to every registered device of a user.
 * When Firebase is not configured the dispatcher stays silent, so the rest of
 * the application (and the in-app notification centre) keeps working.
 */
@Component
public class PushDispatcher {

    private static final Logger log = LoggerFactory.getLogger(PushDispatcher.class);
    private static final int MAX_TOKENS_PER_BATCH = 400;

    private final DeviceTokenRepository deviceTokenRepository;
    private final FirebaseMessaging messaging;

    public PushDispatcher(DeviceTokenRepository deviceTokenRepository,
                          @Value("${app.fcm.service-account-json:}") String serviceAccountJson,
                          @Value("${app.fcm.service-account-file:}") String serviceAccountFile,
                          @Value("${app.fcm.project-id:}") String projectId) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.messaging = initializeMessaging(serviceAccountJson, serviceAccountFile, projectId);
    }

    public boolean isAvailable() {
        return messaging != null;
    }

    @Async("pushExecutor")
    @Transactional
    public void dispatch(String title, String body, Map<String, String> data, List<String> tokens) {
        if (messaging == null || tokens == null || tokens.isEmpty()) {
            return;
        }
        for (int start = 0; start < tokens.size(); start += MAX_TOKENS_PER_BATCH) {
            List<String> batch = tokens.subList(start, Math.min(start + MAX_TOKENS_PER_BATCH, tokens.size()));
            try {
                MulticastMessage message = MulticastMessage.builder()
                        .addAllTokens(batch)
                        .setNotification(com.google.firebase.messaging.Notification.builder()
                                .setTitle(title)
                                .setBody(body)
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.HIGH)
                                .build())
                        .setWebpushConfig(WebpushConfig.builder()
                                .setNotification(WebpushNotification.builder()
                                        .setTitle(title)
                                        .setBody(body)
                                        .setIcon("/icons/Icon-192.png")
                                        .build())
                                .putAllData(data == null ? Map.of() : data)
                                .build())
                        .putAllData(data == null ? Map.of() : data)
                        .build();
                BatchResponse response = messaging.sendEachForMulticast(message);
                deactivateInvalidTokens(batch, response);
            } catch (FirebaseMessagingException ex) {
                log.warn("FCM multicast failed: {}", ex.getMessage());
            } catch (Exception ex) {
                log.warn("Unexpected FCM error: {}", ex.getMessage());
            }
        }
    }

    private void deactivateInvalidTokens(List<String> tokens, BatchResponse response) {
        List<SendResponse> responses = response.getResponses();
        for (int index = 0; index < responses.size() && index < tokens.size(); index++) {
            SendResponse sendResponse = responses.get(index);
            if (sendResponse.isSuccessful()) {
                continue;
            }
            FirebaseMessagingException exception = sendResponse.getException();
            MessagingErrorCode code = exception == null ? null : exception.getMessagingErrorCode();
            if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
                try {
                    deviceTokenRepository.deactivateByToken(tokens.get(index));
                } catch (Exception ex) {
                    log.debug("Could not deactivate an invalid FCM token: {}", ex.getMessage());
                }
            }
        }
    }

    private FirebaseMessaging initializeMessaging(String json, String file, String projectId) {
        try {
            InputStream credentialsStream = resolveCredentials(json, file);
            if (credentialsStream == null) {
                log.info("FCM is not configured. In-app notifications remain available.");
                return null;
            }
            GoogleCredentials credentials = GoogleCredentials.fromStream(credentialsStream);
            FirebaseOptions.Builder options = FirebaseOptions.builder().setCredentials(credentials);
            String resolvedProject = projectId == null ? "" : projectId.trim();
            if (resolvedProject.isEmpty() && credentials instanceof ServiceAccountCredentials serviceAccount) {
                resolvedProject = serviceAccount.getProjectId();
            }
            if (!resolvedProject.isEmpty()) {
                options.setProjectId(resolvedProject);
            }
            FirebaseApp app;
            if (FirebaseApp.getApps().isEmpty()) {
                app = FirebaseApp.initializeApp(options.build());
            } else {
                app = FirebaseApp.getInstance();
            }
            log.info("FCM push notifications are enabled.");
            return FirebaseMessaging.getInstance(app);
        } catch (Exception ex) {
            log.warn("FCM could not be initialised ({}). In-app notifications remain available.", ex.getMessage());
            return null;
        }
    }

    private InputStream resolveCredentials(String json, String file) throws Exception {
        String raw = json == null ? "" : json.trim();
        if (!raw.isEmpty()) {
            if (raw.startsWith("{")) {
                return new ByteArrayInputStream(raw.getBytes(StandardCharsets.UTF_8));
            }
            File candidate = new File(raw);
            if (candidate.isFile()) {
                return new FileInputStream(candidate);
            }
            byte[] decoded = Base64.getDecoder().decode(raw);
            return new ByteArrayInputStream(decoded);
        }
        String path = file == null ? "" : file.trim();
        if (!path.isEmpty()) {
            File candidate = new File(path);
            if (candidate.isFile()) {
                return new FileInputStream(candidate);
            }
        }
        return null;
    }

    public List<String> sanitize(List<String> tokens) {
        if (tokens == null) {
            return List.of();
        }
        List<String> clean = new ArrayList<>();
        for (String token : tokens) {
            if (token != null && !token.isBlank()) {
                clean.add(token.trim());
            }
        }
        return clean;
    }
}
