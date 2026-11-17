import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration supplied at build time.
///
/// ```powershell
/// flutter run -d chrome --no-web-resources-cdn `
///   --dart-define=FIREBASE_API_KEY=... `
///   --dart-define=FIREBASE_APP_ID=... `
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
///   --dart-define=FIREBASE_PROJECT_ID=... `
///   --dart-define=FIREBASE_VAPID_KEY=...
/// ```
///
/// When the values are absent the app still runs; push notifications are simply
/// skipped and the in-app notification centre keeps working.
class AppFirebaseOptions {
  AppFirebaseOptions._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        measurementId: measurementId.isEmpty ? null : measurementId,
      );
}
