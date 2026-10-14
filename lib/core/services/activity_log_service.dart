import '../network/api_client.dart';

class ActivityLogService {
  static final ApiClient _apiClient = ApiClient();

  /// Mengirim log aktivitas ke server backend
  static Future<void> log(String activity, {String type = 'main', dynamic payload}) async {
    try {
      await _apiClient.post(
        '/activity-logs/mobile',
        body: {
          'activity': activity.trim(),
          'type': type,
          'payload': payload ?? [],
        },
      );
    } catch (_) {
      // Abaikan error agar tidak mengganggu interaksi pengguna di mobile
    }
  }

  /// Shortcut untuk log aktivitas utama (Main Log)
  static Future<void> logMain(String activity, [dynamic payload]) =>
      log(activity, type: 'main', payload: payload);

  /// Shortcut untuk log aktivitas sekunder (Secondary Log)
  static Future<void> logSecondary(String activity, [dynamic payload]) =>
      log(activity, type: 'secondary', payload: payload);
}
