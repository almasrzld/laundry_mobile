import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class IconHelper {
  /// Mengambil Lucide Icon berdasarkan string identifier dari backend
  static IconData getServiceIcon(String code) {
    final cleanCode = code.toLowerCase().replaceAll('-', '_');
    switch (cleanCode) {
      case 'shirt':
      case 'wash':
      case 'washing_machine':
      case 'local_laundry_service':
        return LucideIcons.shirt;
      case 'wind':
      case 'waves':
      case 'dry':
        return LucideIcons.wind;
      case 'sparkles':
      case 'iron':
      case 'steam':
        return LucideIcons.sparkles;
      case 'zap':
      case 'bolt':
      case 'flash':
      case 'express':
        return LucideIcons.zap;
      case 'bed':
      case 'bed_double':
      case 'blanket':
        return LucideIcons.bedDouble;
      case 'footprints':
      case 'shoe':
      case 'shoes':
      case 'roller_skating':
        return LucideIcons.footprints;
      case 'hanger':
      case 'dress':
      case 'suit':
      case 'checkroom':
        return LucideIcons.gem;
      default:
        return LucideIcons.shirt;
    }
  }

  /// Mengambil Lucide Icon untuk Promo & Voucher
  static IconData getPromoIcon(String code) {
    final cleanCode = code.toLowerCase().replaceAll('-', '_');
    switch (cleanCode) {
      case 'ticket':
      case 'ticket_percent':
      case 'discount':
      case 'local_offer':
        return LucideIcons.ticket;
      case 'truck':
      case 'shipping':
      case 'local_shipping':
      case 'delivery':
        return LucideIcons.truck;
      case 'sparkles':
      case 'weekend':
      case 'star':
        return LucideIcons.sparkles;
      case 'gift':
        return LucideIcons.gift;
      default:
        return LucideIcons.ticket;
    }
  }
}
