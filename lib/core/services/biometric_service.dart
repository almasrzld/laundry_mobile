import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  static BiometricService get instance => _instance;

  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyBiometricToken = 'biometric_auth_token';
  static const String _keyBiometricUserData = 'biometric_user_data';

  /// Cek apakah saat ini berjalan di mode simulator development (Web atau platform tanpa sensor native)
  bool get isDevSimulationMode =>
      kDebugMode && (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS));

  /// Memeriksa apakah perangkat memiliki hardware biometrik dan sudah ada sidik jari/wajah yang terdaftar
  Future<bool> isBiometricSupported() async {
    // Mode Simulasi Khusus Development (Web / Desktop tanpa sensor)
    if (isDevSimulationMode) {
      return true;
    }

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Pengecekan hardware gagal: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan daftar tipe biometrik yang tersedia di perangkat
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (isDevSimulationMode) {
      return [BiometricType.fingerprint];
    }
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Memeriksa apakah perangkat mendukung Face ID secara spesifik
  Future<bool> isFaceId() async {
    final available = await getAvailableBiometrics();
    return available.contains(BiometricType.face);
  }

  /// Nama tampilan biometrik yang ramah pengguna (Face ID vs Sidik Jari)
  Future<String> getBiometricDisplayName() async {
    if (await isFaceId()) {
      return 'Face ID';
    }
    return 'Sidik Jari';
  }

  /// Helper penulisan penyimpanan aman dengan fallback SharedPreferences (khusus Web & dev)
  Future<void> _writeStorage(String key, String value) async {
    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sec_$key', value);
    } catch (_) {}
  }

  /// Helper pembacaan penyimpanan aman
  Future<String?> _readStorage(String key) async {
    try {
      if (!kIsWeb) {
        final val = await _secureStorage.read(key: key);
        if (val != null && val.isNotEmpty) return val;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('sec_$key');
    } catch (_) {
      return null;
    }
  }

  /// Helper penghapusan penyimpanan aman
  Future<void> _deleteStorage(String key) async {
    try {
      if (!kIsWeb) {
        await _secureStorage.delete(key: key);
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sec_$key');
    } catch (_) {}
  }

  /// Memeriksa apakah fitur biometrik telah diaktifkan oleh pengguna
  Future<bool> isBiometricEnabled() async {
    try {
      final enabledStr = await _readStorage(_keyBiometricEnabled);
      if (enabledStr != 'true') return false;

      // Pastikan token tersimpan juga ada
      final token = await _readStorage(_keyBiometricToken);
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Mengatur preferensi toggle biometrik pengguna
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _writeStorage(_keyBiometricEnabled, enabled ? 'true' : 'false');
      if (!enabled) {
        await clearBiometricSession();
      }
    } catch (e) {
      debugPrint('[BiometricService] Gagal menyimpan preferensi biometrik: $e');
    }
  }

  /// Menyimpan kredensial token dan user data ke Secure Storage (Keystore/Keychain/Web Storage)
  Future<void> saveBiometricSession({
    required String token,
    required UserModel user,
  }) async {
    try {
      await _writeStorage(_keyBiometricEnabled, 'true');
      await _writeStorage(_keyBiometricToken, token);
      await _writeStorage(_keyBiometricUserData, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[BiometricService] Gagal menyimpan sesi biometrik: $e');
    }
  }

  /// Mengambil token tersimpan dari Secure Storage
  Future<String?> getStoredToken() async {
    return await _readStorage(_keyBiometricToken);
  }

  /// Mengambil data user tersimpan dari Secure Storage
  Future<UserModel?> getStoredUser() async {
    try {
      final raw = await _readStorage(_keyBiometricUserData);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Menghapus kredensial biometrik (misal saat ganti akun atau token invalid)
  Future<void> clearBiometricSession() async {
    try {
      await _deleteStorage(_keyBiometricToken);
      await _deleteStorage(_keyBiometricUserData);
    } catch (e) {
      debugPrint('[BiometricService] Gagal menghapus sesi biometrik: $e');
    }
  }

  /// Menghapus total data biometrik termasuk preferensi aktivasi
  Future<void> resetAll() async {
    try {
      await _deleteStorage(_keyBiometricEnabled);
      await _deleteStorage(_keyBiometricToken);
      await _deleteStorage(_keyBiometricUserData);
    } catch (e) {
      debugPrint('[BiometricService] Gagal reset data biometrik: $e');
    }
  }

  /// Memunculkan prompt biometrik native dari sistem operasi (atau simulasi jika dev mode di Web)
  Future<bool> authenticate({String? reason}) async {
    // Mode Simulasi Khusus Development (Web / Desktop tanpa hardware sensor)
    if (isDevSimulationMode) {
      debugPrint('[BiometricService - Dev Simulator] Verifikasi biometrik berhasil disimulasikan: $reason');
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    try {
      final canCheck = await isBiometricSupported();
      if (!canCheck) return false;

      final displayName = await getBiometricDisplayName();
      final defaultReason = 'Verifikasi $displayName untuk masuk ke Almas Laundry';

      return await _localAuth.authenticate(
        localizedReason: reason ?? defaultReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Autentikasi biometrik dibatalkan/gagal: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] Error tak terduga: $e');
      return false;
    }
  }
}
