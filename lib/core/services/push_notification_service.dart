import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../services/session_service.dart';
import 'notification_realtime_service.dart';

// Top-level background message handler wajib di-declare di luar class
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  // Pesan di background otomatis ditangani oleh OS Android/iOS
  debugPrint('📬 [FCM Background Message]: ${message.notification?.title} - ${message.notification?.body}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  PushNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _isFirebaseReady = false;
  static String? _cachedFcmToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'almas_laundry_notifications',
    'Notifikasi Almas Laundry',
    description: 'Kanal resmi untuk pembaruan status cucian, kurir, dan pembayaran',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inisialisasi Firebase & Push Notification Service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi Firebase Core secara aman
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isFirebaseReady = true;
        debugPrint('🔥 [Firebase FCM]: Firebase Core siap digunakan (${kIsWeb ? "Web" : defaultTargetPlatform.name})');
      } catch (e) {
        debugPrint('ℹ️ [FCM Info]: Inisialisasi Firebase dilewati/gagal pada platform ini: $e');
      }

      // 2. Inisialisasi Flutter Local Notifications (untuk banner saat aplikasi terbuka / foreground)
      if (!kIsWeb) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNotificationClick(response.payload);
          },
        );

        // Daftarkan channel notifikasi di Android
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_channel);
        }
      }

      // 3. Konfigurasi Firebase Messaging jika Firebase siap
      if (_isFirebaseReady) {
        final messaging = FirebaseMessaging.instance;

        // Set background handler (khusus native mobile)
        if (!kIsWeb) {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        }

        // Minta izin notifikasi (Android 13+ & iOS)
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        debugPrint('🔔 [FCM Permission Status]: ${settings.authorizationStatus}');

        // Dapatkan token FCM awal
        try {
          _cachedFcmToken = await messaging.getToken();
          debugPrint('🔑 [FCM Token]: $_cachedFcmToken');
          if (_cachedFcmToken != null) {
            await syncTokenWithBackend(_cachedFcmToken!);
          }
        } catch (e) {
          debugPrint('⚠️ [FCM Get Token Error]: $e');
        }

        // Listener token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _cachedFcmToken = newToken;
          debugPrint('🔄 [FCM Token Refreshed]: $newToken');
          syncTokenWithBackend(newToken);
        });

        // 4. Listener saat pesan masuk di FOREGROUND (Aplikasi sedang dibuka)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📲 [FCM Foreground Message]: ${message.notification?.title}');
          _showLocalNotification(message);
          // Trigger pembaruan badge lonceng secara instan
          NotificationRealtimeService.instance.refresh(isFromSse: true);
        });

        // 5. Listener saat notifikasi di klik dari BACKGROUND
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('🚀 [FCM Message Opened App]: ${message.data}');
          _handleMessageData(message.data);
        });

        // 6. Cek notifikasi saat aplikasi dibuka dari keadaan TERMINATED / DITUTUP TOTAL
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('⚡ [FCM Initial Message]: ${initialMessage.data}');
          _handleMessageData(initialMessage.data);
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService Init Error]: $e');
    }
  }

  /// Menampilkan banner notifikasi lokal saat aplikasi di Foreground
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Almas Laundry',
      body: notification.body ?? '',
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Handler klik notifikasi
  static void _handleNotificationClick(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      _handleMessageData(data);
    } catch (_) {}
  }

  /// Handler aksi data notifikasi (Deep-linking / navigasi)
  static void _handleMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    final orderId = data['orderId'];

    debugPrint('🧭 [FCM Navigation Action]: type=$type, orderId=$orderId');
    // Refresh lonceng notifikasi
    NotificationRealtimeService.instance.refresh(isFromSse: true);
  }

  /// Mengirim token FCM ke backend untuk disimpan di tabel user_devices
  static Future<void> syncTokenWithBackend([String? token]) async {
    try {
      final fcmToken = token ?? _cachedFcmToken;
      if (fcmToken == null || fcmToken.isEmpty) return;

      final authToken = await SessionService.getToken();
      if (authToken == null || authToken.isEmpty) return;

      final apiClient = ApiClient();
      await apiClient.post(
        ApiEndpoints.fcmToken,
        body: {
          'fcm_token': fcmToken,
          'device_type': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'device_name': 'Mobile App',
        },
      );
      debugPrint('✅ [FCM Token Synced with Backend]');
    } catch (e) {
      debugPrint('⚠️ [FCM Token Sync Error]: $e');
    }
  }

  /// Menghapus token FCM dari backend saat logout
  static Future<void> removeTokenFromBackend() async {
    try {
      if (_cachedFcmToken == null || _cachedFcmToken!.isEmpty) return;

      final authToken = await SessionService.getToken();
      if (authToken == null || authToken.isEmpty) return;

      final apiClient = ApiClient();
      await apiClient.delete(
        ApiEndpoints.fcmToken,
        body: {
          'fcm_token': _cachedFcmToken,
        },
      );
      debugPrint('🗑️ [FCM Token Removed from Backend on Logout]');
    } catch (e) {
      debugPrint('⚠️ [FCM Token Remove Error]: $e');
    }
  }
}
