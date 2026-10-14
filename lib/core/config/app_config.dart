import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central application configuration.
/// Flow: .env -> AppConfig -> Application Code
/// Purely reads from environment variables without hardcoded fallbacks.
class AppConfig {
  static String get appName => dotenv.env['APP_NAME'] ?? '';

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static String get apiAndroidBaseUrl => dotenv.env['API_ANDROID_BASE_URL'] ?? '';

  static String get frontendWebUrl => dotenv.env['FRONTEND_WEB_URL'] ?? '';

  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? '';

  static int get autoLogoutMinutes =>
      int.tryParse(dotenv.env['AUTO_LOGOUT_MINUTES'] ?? '') ?? 0;

  static Duration get autoLogoutDuration => Duration(minutes: autoLogoutMinutes);

  /// Platform-aware dynamic base URL computed purely from config
  static String get baseUrl {
    if (kIsWeb) {
      return apiBaseUrl;
    }
    try {
      if (Platform.isAndroid) {
        return apiAndroidBaseUrl.isNotEmpty ? apiAndroidBaseUrl : apiBaseUrl;
      }
    } catch (_) {}
    return apiBaseUrl;
  }

  // Firebase Cloud Messaging & Service Configuration
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseAuthDomain =>
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseWebAppId => dotenv.env['FIREBASE_WEB_APP_ID'] ?? '';
  static String get firebaseAndroidAppId =>
      dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '';
  static String get firebaseIosAppId => dotenv.env['FIREBASE_IOS_APP_ID'] ?? '';

  /// Returns true if core Firebase configuration is present in .env
  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
}
