import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../widgets/session_expired_dialog.dart';
import 'notification_realtime_service.dart';
import 'session_service.dart';
import '../../features/auth/presentation/pages/login_page.dart';

class SessionManager {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isSessionExpiredDialogShowing = false;
  static Timer? _inactivityCheckTimer;
  static int _lastRecordedTime = 0;

  static void init() {
    _inactivityCheckTimer?.cancel();
    // Periodically check for inactivity timeout every 10 seconds
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkInactivity();
    });
  }

  static void dispose() {
    _inactivityCheckTimer?.cancel();
  }

  static void recordActivity() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle activity recording to at most once every 3 seconds to preserve performance
    if (now - _lastRecordedTime > 3000) {
      _lastRecordedTime = now;
      SessionService.recordActivity();
    }
  }

  static Future<void> checkInactivity() async {
    if (_isSessionExpiredDialogShowing) return;

    final isExpired = await SessionService.isSessionExpired(AppConfig.autoLogoutDuration);
    if (isExpired) {
      await handleSessionExpired(
        message:
            'Sesi Anda telah berakhir karena tidak ada aktivitas selama ${AppConfig.autoLogoutMinutes} menit. Silakan masuk kembali.',
      );
    }
  }

  static Future<void> handleSessionExpired({String? message}) async {
    if (_isSessionExpiredDialogShowing) return;

    final loggedIn = await SessionService.isLoggedIn();
    if (!loggedIn) return;

    _isSessionExpiredDialogShowing = true;
    
    // Stop real-time notification listener and background polling
    NotificationRealtimeService.instance.stop();

    await SessionService.clearSession();

    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null) {
          SessionExpiredDialog.show(
            currentContext,
            message: message,
            onConfirm: () {
              _isSessionExpiredDialogShowing = false;
            },
          );
        } else {
          _isSessionExpiredDialogShowing = false;
        }
      });
    } else {
      _isSessionExpiredDialogShowing = false;
    }
  }
}
