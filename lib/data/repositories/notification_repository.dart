import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/notification_model.dart';

abstract class INotificationRepository {
  Future<List<NotificationModel>> getNotifications();
  Future<int> getUnreadCount();
  Future<bool> markAsRead(String id);
  Future<bool> markAllAsRead();
}

class NotificationRepository implements INotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final response = await _apiClient.get(ApiEndpoints.notifications);
    List<NotificationModel> list = [];

    if (response is List) {
      list = response
          .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is Map && response['data'] is List) {
      list = (response['data'] as List)
          .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return list;
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.unreadNotificationCount);
      if (response is Map && response['unread_count'] != null) {
        return int.tryParse(response['unread_count'].toString()) ?? 0;
      }
      if (response is Map && response['data'] is Map && response['data']['unread_count'] != null) {
        return int.tryParse(response['data']['unread_count'].toString()) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<bool> markAsRead(String id) async {
    try {
      await _apiClient.patch(ApiEndpoints.markNotificationRead(id), {});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead() async {
    try {
      await _apiClient.patch(ApiEndpoints.markAllNotificationsRead, {});
      return true;
    } catch (_) {
      return false;
    }
  }
}
