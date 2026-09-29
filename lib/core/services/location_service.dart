import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_colors.dart';

class LocationResult {
  final String fullAddress;
  final String suggestedLabel;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.fullAddress,
    required this.suggestedLabel,
    required this.latitude,
    required this.longitude,
  });
}

class LocationService {
  /// Memeriksa status GPS dan izin lokasi, menampilkan dialog interaktif jika belum aktif
  static Future<bool> ensureLocationPermission(BuildContext context) async {
    // 1. Pada perangkat native (Android/iOS), periksa apakah GPS aktif
    if (!kIsWeb) {
      try {
        final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!isServiceEnabled) {
          if (!context.mounted) return false;
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.mapPinOff, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aktifkan GPS / Lokasi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Layanan GPS perangkat Anda sedang nonaktif. Aktifkan GPS agar aplikasi dapat mendeteksi lokasi penjemputan secara akurat.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.settings, size: 16),
                  label: const Text('Buka Pengaturan Lokasi'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await Geolocator.openLocationSettings();
          }
          return false;
        }
      } catch (_) {}
    }

    // 2. Periksa status izin lokasi (Permission)
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('Izin akses lokasi ditolak. Silakan izinkan lokasi untuk menggunakan fitur ini.'),
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return false;
        final shouldOpenAppSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.shieldAlert, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Izin Lokasi Diperlukan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Izin akses lokasi ditolak secara permanen. Silakan buka Pengaturan aplikasi/browser untuk mengaktifkan izin lokasi.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );

        if (shouldOpenAppSettings == true && !kIsWeb) {
          await Geolocator.openAppSettings();
        }
        return false;
      }
    } catch (_) {
      // Jika platform channel belum terhubung pada web dev session, izinkan lanjut ke fallback
    }

    return true;
  }

  /// Mendapatkan koordinat terkini dan menerjemahkannya ke alamat jalan (Reverse Geocoding)
  static Future<LocationResult?> getCurrentLocationWithAddress(BuildContext context) async {
    final hasPermission = await ensureLocationPermission(context);
    if (!hasPermission) return null;

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (geoErr) {
        debugPrint('Geolocator GPS error/unlinked: $geoErr');
      }

      double lat = 0.0;
      double lon = 0.0;
      String? addressName;

      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
        addressName = await reverseGeocode(lat, lon);
      } else {
        // Fallback cerdas: Deteksi koordinat dari IP Geolocation
        final ipLoc = await _getFallbackIpLocation();
        if (ipLoc != null) {
          lat = ipLoc['lat'] ?? 0.0;
          lon = ipLoc['lon'] ?? 0.0;
          addressName = await reverseGeocode(lat, lon);
          if ((addressName.isEmpty || addressName.startsWith('Lokasi GPS')) && ipLoc['city'] != null) {
            addressName = '${ipLoc['city']}, ${ipLoc['regionName'] ?? ''}';
          }
        }
      }

      if (lat == 0.0 && lon == 0.0) {
        throw Exception('Tidak dapat mendeteksi koordinat lokasi.');
      }

      return LocationResult(
        fullAddress: addressName?.isNotEmpty == true ? addressName! : 'Lokasi Terdeteksi (${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)})',
        suggestedLabel: 'Lokasi Terkini',
        latitude: lat,
        longitude: lon,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Gagal mengambil lokasi: ${e.toString().replaceAll("Exception: ", "")}'),
          ),
        );
      }
      return null;
    }
  }

  /// Fallback deteksi lokasi via IP ketika GPS / platform channel web belum terhubung
  static Future<Map<String, dynamic>?> _getFallbackIpLocation() async {
    try {
      final res = await http.get(
        Uri.parse('http://ip-api.com/json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          return {
            'lat': (data['lat'] as num?)?.toDouble() ?? 0.0,
            'lon': (data['lon'] as num?)?.toDouble() ?? 0.0,
            'city': data['city']?.toString() ?? '',
            'regionName': data['regionName']?.toString() ?? '',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Reverse Geocoding menggunakan OpenStreetMap Nominatim
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'AlmasLaundryApp/1.0 (customer-location)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString();
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          final parts = <String>[];
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['suburb'];
          if (road != null) parts.add(road.toString());

          final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? addr['village'];
          if (city != null) parts.add(city.toString());

          final state = addr['state'];
          if (state != null) parts.add(state.toString());

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        if (displayName != null && displayName.isNotEmpty) {
          final items = displayName.split(', ');
          if (items.length > 4) {
            return items.take(4).join(', ');
          }
          return displayName;
        }
      }
    } catch (_) {}

    return 'Lokasi GPS (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
  }
}
