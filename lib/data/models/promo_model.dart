import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/icon_helper.dart';

class PromoModel {
  final String id;
  final String title;
  final String subtitle;
  final String code;
  final String category; // 'event' | 'reward_point'
  final String benefitType; // 'service_discount' | 'delivery_discount' | 'free_delivery'
  final String discountType; // 'fixed' | 'percent'
  final int discountAmount;
  final int? maxDiscount;
  final int minOrderAmount;
  final int pointsSpent;
  final int pointsRequired;
  final String? startDate;
  final String? endDate;
  final String iconCode;
  final int colorHex;
  final bool isUsed;
  final String? usedAt;
  final String? orderId;
  final String? createdAt;

  const PromoModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    this.category = 'Event',
    this.benefitType = 'Potongan Harga',
    this.discountType = 'Nominal',
    required this.discountAmount,
    this.maxDiscount,
    required this.minOrderAmount,
    this.pointsSpent = 0,
    this.pointsRequired = 0,
    this.startDate,
    this.endDate,
    required this.iconCode,
    required this.colorHex,
    this.isUsed = false,
    this.usedAt,
    this.orderId,
    this.createdAt,
  });

  IconData get icon => IconHelper.getPromoIcon(iconCode);

  Color get color => Color(colorHex);

  bool get isEvent => category.toLowerCase() == 'event';
  bool get isRewardPoint => category.toLowerCase() == 'reward point' || category.toLowerCase() == 'reward_point';
  bool get isFreeDelivery => benefitType.toLowerCase() == 'bebas ongkir' || benefitType.toLowerCase() == 'free delivery' || benefitType.toLowerCase() == 'free_delivery';
  bool get isDeliveryDiscount => benefitType.toLowerCase() == 'potongan ongkir' || benefitType.toLowerCase() == 'delivery discount' || benefitType.toLowerCase() == 'delivery_discount';
  bool get isServiceDiscount => benefitType.toLowerCase() == 'potongan harga' || benefitType.toLowerCase() == 'service discount' || benefitType.toLowerCase() == 'service_discount';
  bool get isPercentage => discountType.toLowerCase() == 'persen' || discountType.toLowerCase() == 'percent';
  bool get isFixed => discountType.toLowerCase() == 'nominal' || discountType.toLowerCase() == 'fixed';

  bool get isExpired {
    if (endDate == null || endDate!.trim().isEmpty) return false;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final clean = endDate!.trim().split('T')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final end = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return end.isBefore(today);
      }
    } catch (_) {}
    return false;
  }

  bool get isNotStarted {
    if (startDate == null || startDate!.trim().isEmpty) return false;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final clean = startDate!.trim().split('T')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final start = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return start.isAfter(today);
      }
    } catch (_) {}
    return false;
  }

  bool get isValidPeriod => !isExpired && !isNotStarted;

  String get formattedPeriod {
    if (startDate == null && endDate == null) return '';
    final s = _formatSingleDate(startDate);
    final e = _formatSingleDate(endDate);
    if (s.isNotEmpty && e.isNotEmpty) return '$s - $e';
    if (e.isNotEmpty) return 's/d $e';
    return s;
  }

  String _formatSingleDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final clean = raw.trim().split('T')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final day = parts[2];
        final monthIdx = int.parse(parts[1]) - 1;
        final year = parts[0];
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        return '$day ${months[monthIdx]} $year';
      }
    } catch (_) {}
    return raw;
  }

  String get discountLabel {
    if (isFreeDelivery) return 'Bebas Ongkir';
    if (isPercentage) {
      final maxStr = maxDiscount != null && maxDiscount! > 0 ? ' (Maks. ${CurrencyFormatter.formatRupiah(maxDiscount!)})' : '';
      return 'Diskon $discountAmount%$maxStr';
    }
    return 'Potongan ${CurrencyFormatter.formatRupiah(discountAmount)}';
  }

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code_voucher']?.toString() ?? json['code']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ?? json['name_promos']?.toString() ?? json['name']?.toString() ?? '';
    final rawId = json['id']?.toString() ?? json['id_user_vouchers']?.toString() ?? json['id_promos']?.toString() ?? '';
    final isUsedVal = json['is_used'] == true || json['is_used'] == 1 || json['is_used'] == '1';

    return PromoModel(
      id: rawId,
      title: rawTitle,
      subtitle: json['subtitle']?.toString() ?? '',
      code: rawCode.toUpperCase(),
      category: json['category']?.toString() ?? 'Event',
      benefitType: json['benefit_type']?.toString() ?? 'Potongan Harga',
      discountType: json['discount_type']?.toString() ?? 'Nominal',
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      maxDiscount: (json['max_discount'] as num?)?.toInt(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toInt() ?? 0,
      iconCode: json['icon_code']?.toString() ?? 'discount',
      colorHex: (json['color_hex'] as num?)?.toInt() ?? (json['start_color_hex'] as num?)?.toInt() ?? 0xFF0284C7,
      pointsSpent: (json['points_spent'] as num?)?.toInt() ?? (json['points_required'] as num?)?.toInt() ?? 0,
      pointsRequired: (json['points_required'] as num?)?.toInt() ?? (json['points_spent'] as num?)?.toInt() ?? 0,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      isUsed: isUsedVal,
      usedAt: json['used_at']?.toString(),
      orderId: json['order_id']?.toString() ?? json['orders_id']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'code': code,
      'code_voucher': code,
      'category': category,
      'benefit_type': benefitType,
      'discount_type': discountType,
      'discount_amount': discountAmount,
      'max_discount': maxDiscount,
      'min_order_amount': minOrderAmount,
      'points_spent': pointsSpent,
      'points_required': pointsRequired,
      'start_date': startDate,
      'end_date': endDate,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'is_used': isUsed,
      'used_at': usedAt,
      'orders_id': orderId,
      'created_at': createdAt,
    };
  }
}
