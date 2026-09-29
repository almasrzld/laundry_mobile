import 'package:flutter/material.dart';
import '../../core/utils/icon_helper.dart';

enum ServiceCategoryType {
  all,
  kiloan,
  satuan,
  express,
  specialty;

  String toApiString() {
    switch (this) {
      case ServiceCategoryType.all:
        return 'all';
      case ServiceCategoryType.kiloan:
        return 'kiloan';
      case ServiceCategoryType.satuan:
        return 'satuan';
      case ServiceCategoryType.express:
        return 'express';
      case ServiceCategoryType.specialty:
        return 'specialty';
    }
  }

  static ServiceCategoryType fromApiString(String val) {
    final v = val.toLowerCase().trim();
    if (v.contains('kilo')) return ServiceCategoryType.kiloan;
    if (v.contains('satuan')) return ServiceCategoryType.satuan;
    if (v.contains('express') || v.contains('kilat') || v.contains('cepat')) return ServiceCategoryType.express;
    if (v.contains('sepatu') || v.contains('tas') || v.contains('special') || v.contains('khusus')) return ServiceCategoryType.specialty;
    return ServiceCategoryType.all;
  }
}

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final String unit; // 'kg', 'pcs', 'pasang'
  final String duration;
  final String iconCode;
  final String categoryId;
  final String categoryCode;
  final ServiceCategoryType category;
  final String categoryName;
  final bool isPopular;
  final int badgeColorHex;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.unit,
    required this.duration,
    required this.iconCode,
    this.categoryId = '',
    this.categoryCode = '',
    required this.category,
    this.categoryName = '',
    this.isPopular = false,
    this.badgeColorHex = 0xFF0284C7,
  });

  IconData get icon => IconHelper.getServiceIcon(iconCode);

  Color get badgeColor => Color(badgeColorHex);

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? json['name_services']?.toString() ?? '';
    final unit = json['unit']?.toString() ?? json['unit_code']?.toString() ?? json['unit_name']?.toString() ?? 'kg';
    final catCode = json['category']?.toString() ?? json['category_code']?.toString() ?? '';
    final catName = json['category_name']?.toString() ?? json['name_service_categories']?.toString() ?? catCode;
    final catId = json['category_id']?.toString() ?? 
        json['service_category_id']?.toString() ?? 
        json['service_categories_id']?.toString() ?? '';

    return ServiceModel(
      id: json['id']?.toString() ?? json['id_services']?.toString() ?? '',
      name: name,
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      unit: unit,
      duration: json['duration']?.toString() ?? '1-2 Hari',
      iconCode: json['icon_code']?.toString() ?? json['icon']?.toString() ?? 'wash',
      categoryId: catId,
      categoryCode: catCode,
      category: ServiceCategoryType.fromApiString(catCode.isNotEmpty ? catCode : catName),
      categoryName: catName,
      isPopular: json['is_popular'] == true || json['is_popular'] == 1,
      badgeColorHex: (json['badge_color_hex'] as num?)?.toInt() ?? 0xFF0284C7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'unit': unit,
      'duration': duration,
      'icon_code': iconCode,
      'category_id': categoryId,
      'category_code': categoryCode,
      'category': category.toApiString(),
      'category_name': categoryName,
      'is_popular': isPopular,
      'badge_color_hex': badgeColorHex,
    };
  }

  ServiceModel copyWith({
    String? id,
    String? name,
    String? description,
    int? price,
    String? unit,
    String? duration,
    String? iconCode,
    String? categoryId,
    String? categoryCode,
    ServiceCategoryType? category,
    String? categoryName,
    bool? isPopular,
    int? badgeColorHex,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      duration: duration ?? this.duration,
      iconCode: iconCode ?? this.iconCode,
      categoryId: categoryId ?? this.categoryId,
      categoryCode: categoryCode ?? this.categoryCode,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      isPopular: isPopular ?? this.isPopular,
      badgeColorHex: badgeColorHex ?? this.badgeColorHex,
    );
  }
}
