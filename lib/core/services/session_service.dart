import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

class SessionService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'user_data';
  static const String _keyLastActivity = 'last_activity_time';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveSession({required String token, required UserModel user}) async {
    await init();
    await _prefs?.setString(_keyToken, token);
    await _prefs?.setString(_keyUser, jsonEncode(user.toJson()));
    await recordActivity();
  }

  static Future<String?> getToken() async {
    await init();
    return _prefs?.getString(_keyToken);
  }

  static Future<UserModel?> getUser() async {
    await init();
    final raw = _prefs?.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordActivity() async {
    await init();
    await _prefs?.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<int?> getLastActivity() async {
    await init();
    return _prefs?.getInt(_keyLastActivity);
  }

  static Future<bool> isSessionExpired(Duration timeout) async {
    if (timeout.inMilliseconds <= 0) return false;
    await init();
    final loggedIn = await isLoggedIn();
    if (!loggedIn) return false;

    final last = await getLastActivity();
    if (last == null) {
      await recordActivity();
      return false;
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= timeout.inMilliseconds;
  }

  static Future<void> clearSession() async {
    await init();
    await _prefs?.remove(_keyToken);
    await _prefs?.remove(_keyUser);
    await _prefs?.remove(_keyLastActivity);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
