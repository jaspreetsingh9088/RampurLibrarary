import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration, injected at build time with
/// `--dart-define-from-file=dart_defines.json` (CI writes that file from GitHub secrets).
///
/// Nothing secret lives here — Firebase client keys are public identifiers and access
/// is enforced by Firestore / Storage security rules.
class AppConfig {
  AppConfig._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.rampurlibrary.app');
  static const iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');

  /// Web push certificate key (Firebase console → Cloud Messaging → Web Push certificates).
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Public website (SEO catalogue) — used for share links.
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://rampurlibrary.vercel.app');

  /// Region the Cloud Functions are deployed to.
  static const functionsRegion = 'asia-south1';

  static String get _appId {
    if (kIsWeb) return webAppId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return iosAppId;
      default:
        return androidAppId;
    }
  }

  static bool get isConfigured => apiKey.isNotEmpty && projectId.isNotEmpty && _appId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: apiKey,
        appId: _appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        authDomain: kIsWeb ? (authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain) : null,
        measurementId: kIsWeb && measurementId.isNotEmpty ? measurementId : null,
        iosBundleId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? iosBundleId : null,
        iosClientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isNotEmpty ? iosClientId : null,
      );

  /// Initialise Firebase. Returns false when the build has no Firebase config, so the
  /// app can show a setup screen instead of crashing.
  static Future<bool> initFirebase() async {
    if (!isConfigured) return false;
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: firebaseOptions);
      } on FirebaseException catch (e) {
        // On Android/iOS with google-services files present the native SDK may already
        // have created the default app.
        if (e.code != 'duplicate-app') rethrow;
      }
    }
    return true;
  }
}
