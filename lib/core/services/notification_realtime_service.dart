import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../services/session_service.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import 'sse/sse_client.dart';

class NotificationRealtimeService {
  static final NotificationRealtimeService _instance = NotificationRealtimeService._internal();
  static NotificationRealtimeService get instance => _instance;

  NotificationRealtimeService._internal();

  final INotificationRepository _repository = NotificationRepository();
  SseClient? _sseClient;
  StreamSubscription<String>? _sseSubscription;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  bool _isRunning = false;

  // Notifiers
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<NotificationModel>> notificationsNotifier = ValueNotifier<List<NotificationModel>>([]);
  final StreamController<NotificationModel> _newNotificationController = StreamController<NotificationModel>.broadcast();
  final StreamController<void> _refreshRequiredController = StreamController<void>.broadcast();

  Stream<NotificationModel> get onNewNotification => _newNotificationController.stream;
  Stream<void> get onRefreshRequired => _refreshRequiredController.stream;

  void triggerRefreshRequired() {
    _refreshRequiredController.add(null);
  }

  final Set<String> _knownNotificationIds = {};
  final Set<String> _alertedNotificationIds = {};

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    final token = await SessionService.getToken();

    // Initial fetch
    await refresh();

    // Connect SSE if token available
    if (token != null && token.isNotEmpty) {
      _connectSse(token);
    }

    // Start background fallback polling (every 12 seconds)
    _startPolling();
  }

  void _connectSse(String token) {
    _cleanupSse();
    try {
      final streamUrl = '${ApiEndpoints.baseUrl}/notifications/stream?token=${Uri.encodeComponent(token)}';
      _sseClient = createPlatformSseClient();
      _sseClient!.connect(streamUrl);

      _sseSubscription = _sseClient!.messageStream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            if (json is Map) {
              final type = json['type'];
              if (type == 'notification_update') {
                // Instantly refresh when server emits notification update
                refresh(isFromSse: true);
              }
            }
          } catch (_) {
            // Heartbeat (: keepalive) or malformed data
          }
        },
        onError: (_) {
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_isRunning) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final token = await SessionService.getToken();
      if (_isRunning && token != null && token.isNotEmpty) {
        _connectSse(token);
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!_isRunning) return;
      await _checkUnreadAndRefresh();
    });
  }

  Future<void> _checkUnreadAndRefresh() async {
    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) return;

      final count = await _repository.getUnreadCount();
      if (count != unreadCountNotifier.value) {
        await refresh();
      }
    } catch (_) {}
  }

  Future<void> refresh({bool isFromSse = false}) async {
    try {
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) {
        unreadCountNotifier.value = 0;
        notificationsNotifier.value = [];
        return;
      }

      final countFuture = _repository.getUnreadCount();
      final listFuture = _repository.getNotifications();

      final results = await Future.wait([countFuture, listFuture]);
      final newCount = results[0] as int;
      final newList = results[1] as List<NotificationModel>;

      // Check for new notifications to trigger in-app alert
      if (_knownNotificationIds.isNotEmpty) {
        final newUnread = newList
            .where((n) =>
                !_knownNotificationIds.contains(n.id) &&
                !_alertedNotificationIds.contains(n.id) &&
                !n.isRead)
            .toList();

        if (newUnread.isNotEmpty) {
          final latest = newUnread.first;
          _alertedNotificationIds.add(latest.id);
          _newNotificationController.add(latest);
        }
      }

      _knownNotificationIds.addAll(newList.map((n) => n.id));
      unreadCountNotifier.value = newCount;
      notificationsNotifier.value = newList;

      // Broadcast refresh event for order / dashboard synchronization
      _refreshRequiredController.add(null);
    } catch (_) {}
  }

  Future<bool> markAsRead(String id) async {
    // Optimistic local update
    final currentList = notificationsNotifier.value;
    final updatedList = currentList.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notificationsNotifier.value = updatedList;

    if (unreadCountNotifier.value > 0) {
      unreadCountNotifier.value = unreadCountNotifier.value - 1;
    }

    final success = await _repository.markAsRead(id);
    if (!success) {
      await refresh();
    }
    return success;
  }

  Future<bool> markAllAsRead() async {
    // Optimistic local update
    final currentList = notificationsNotifier.value;
    final updatedList = currentList.map((n) => n.copyWith(isRead: true)).toList();
    notificationsNotifier.value = updatedList;
    unreadCountNotifier.value = 0;

    final success = await _repository.markAllAsRead();
    if (!success) {
      await refresh();
    }
    return success;
  }

  void _cleanupSse() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseClient?.close();
    _sseClient = null;
  }

  void stop() {
    _isRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSse();
  }
}
