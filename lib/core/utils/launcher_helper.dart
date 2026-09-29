import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherHelper {
  /// Format nomor telepon ke format internasional WhatsApp (62xxxxxxxxxxx)
  static String sanitizePhoneForWhatsApp(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (!clean.startsWith('62')) {
      clean = '62$clean';
    }
    return clean;
  }

  /// Membuka aplikasi dialer/telepon
  static Future<bool> openPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return false;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Membuka chat WhatsApp dengan nomor dan pesan template
  static Future<bool> openWhatsApp({
    required String phone,
    String? message,
  }) async {
    final cleanPhone = sanitizePhoneForWhatsApp(phone);
    final encodedMsg = message != null ? Uri.encodeComponent(message) : '';
    final urlString = encodedMsg.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encodedMsg'
        : 'https://wa.me/$cleanPhone';

    final uri = Uri.parse(urlString);
    try {
      if (kIsWeb) {
        return await launchUrl(uri, webOnlyWindowName: '_blank');
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }

  /// Membuka tautan eksternal
  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (kIsWeb) {
        return await launchUrl(uri, webOnlyWindowName: '_blank');
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }

  /// Membuka lokasi / alamat di Google Maps
  static Future<bool> openGoogleMaps(String address) async {
    if (address.trim().isEmpty) return false;
    final encoded = Uri.encodeComponent(address.trim());
    final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';
    return await openUrl(url);
  }

  /// Menyalin teks ke clipboard perangkat
  static Future<void> copyToClipboard(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Membuka halaman Google Play Store untuk aplikasi
  static Future<bool> openPlayStore({String packageId = 'com.almaslaundry.app'}) async {
    final url = 'https://play.google.com/store/apps/details?id=$packageId';
    return await openUrl(url);
  }

  /// Membuka halaman Apple App Store untuk aplikasi
  static Future<bool> openAppStore({String appId = 'id6400000000'}) async {
    final url = 'https://apps.apple.com/app/$appId';
    return await openUrl(url);
  }
}
