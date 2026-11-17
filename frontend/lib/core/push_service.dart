import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Thin wrapper around Firebase Messaging.
///
/// The app is fully functional without Firebase: when no FIREBASE_* values are
/// supplied this service stays dormant and the in-app notification centre is
/// used instead.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _started = false;
  bool _denied = false;
  String? _token;

  bool get isConfigured => AppFirebaseOptions.configured;
  bool get isDenied => _denied;
  String? get token => _token;

  Future<void> start({
    required Future<void> Function(String token) registerToken,
    required void Function(RemoteMessage message) onMessage,
    bool requestPermission = true,
  }) async {
    if (!AppFirebaseOptions.configured || _started) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
      }
      final messaging = FirebaseMessaging.instance;
      if (requestPermission) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _denied = settings.authorizationStatus == AuthorizationStatus.denied;
        if (_denied) {
          debugPrint('FCM permission was denied. In-app notifications stay enabled.');
          _started = false;
          return;
        }
      }

      String? value;
      if (kIsWeb) {
        if (AppFirebaseOptions.vapidKey.isEmpty) {
          debugPrint(
            'FCM: pass --dart-define=FIREBASE_VAPID_KEY=<web push certificate> '
            'to receive background web pushes.',
          );
          return;
        }
        // ignore: deprecated_member_use
        value = await messaging.getToken(vapidKey: AppFirebaseOptions.vapidKey);
      } else {
        // ignore: deprecated_member_use
        value = await messaging.getToken();
      }
      if (value != null && value.isNotEmpty) {
        _token = value;
        await registerToken(value);
      }
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((refreshed) async {
        _token = refreshed;
        try {
          await registerToken(refreshed);
        } catch (error) {
          debugPrint('Could not refresh the FCM token: $error');
        }
      });
      FirebaseMessaging.onMessage.listen(onMessage);
    } catch (error) {
      debugPrint('Push notifications are unavailable: $error');
      _started = false;
    }
  }

  Future<void> requestPermissionAgain({
    required Future<void> Function(String token) registerToken,
    required void Function(RemoteMessage message) onMessage,
  }) {
    _started = false;
    return start(
      registerToken: registerToken,
      onMessage: onMessage,
      requestPermission: true,
    );
  }
}
