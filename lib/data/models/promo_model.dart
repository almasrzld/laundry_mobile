import 'package:flutter/material.dart';
import '../../core/utils/icon_helper.dart';

class PromoModel {
  final String id;
  final String title;
  final String subtitle;
  final String code;
  final int discountAmount;
  final int minOrderAmount;
  final String iconCode;
  final int colorHex;
  final int pointsSpent;
  final bool isUsed;
  final String? usedAt;
  final String? orderId;
  final String? createdAt;

  const PromoModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.discountAmount,
    required this.minOrderAmount,
    required this.iconCode,
    required this.colorHex,
    this.pointsSpent = 0,
    this.isUsed = false,
    this.usedAt,
    this.orderId,
    this.createdAt,
  });

  IconData get icon => IconHelper.getPromoIcon(iconCode);

  Color get color => Color(colorHex);

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
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toInt() ?? 0,
      iconCode: json['icon_code']?.toString() ?? 'discount',
      colorHex: (json['color_hex'] as num?)?.toInt() ?? (json['start_color_hex'] as num?)?.toInt() ?? 0xFF0284C7,
      pointsSpent: (json['points_spent'] as num?)?.toInt() ?? (json['points_required'] as num?)?.toInt() ?? 0,
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
      'discount_amount': discountAmount,
      'min_order_amount': minOrderAmount,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'points_spent': pointsSpent,
      'is_used': isUsed,
      'used_at': usedAt,
      'orders_id': orderId,
      'created_at': createdAt,
    };
  }
}

