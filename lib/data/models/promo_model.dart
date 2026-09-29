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

  const PromoModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.discountAmount,
    required this.minOrderAmount,
    required this.iconCode,
    required this.colorHex,
  });

  IconData get icon => IconHelper.getPromoIcon(iconCode);

  Color get color => Color(colorHex);

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    return PromoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toInt() ?? 0,
      iconCode: json['icon_code']?.toString() ?? 'discount',
      colorHex: (json['color_hex'] as num?)?.toInt() ?? (json['start_color_hex'] as num?)?.toInt() ?? 0xFF0284C7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'code': code,
      'discount_amount': discountAmount,
      'min_order_amount': minOrderAmount,
      'icon_code': iconCode,
      'color_hex': colorHex,
    };
  }
}
