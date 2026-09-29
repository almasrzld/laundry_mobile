class PerfumeModel {
  final String id;
  final String name;
  final String description;
  final String? code;
  final bool isDefault;

  const PerfumeModel({
    required this.id,
    required this.name,
    this.description = '',
    this.code,
    this.isDefault = false,
  });

  factory PerfumeModel.fromJson(Map<String, dynamic> json) {
    return PerfumeModel(
      id: json['id']?.toString() ?? json['id_perfumes']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_perfumes']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      code: json['code']?.toString(),
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}

class PaymentMethodModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final String? type;
  final String? accountNumber;
  final String? accountName;
  final bool isActive;

  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.type,
    this.accountNumber,
    this.accountName,
    this.isActive = true,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id']?.toString() ?? json['id_payment_methods']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_payment_methods']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString(),
      accountNumber: json['account_number']?.toString(),
      accountName: json['account_name']?.toString(),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}

class MasterOrderStatusModel {
  final String id;
  final String name;
  final String code;
  final int stepOrder;
  final String? colorHex;
  final String? badgeVariant;
  final String? description;
  final bool isActive;

  const MasterOrderStatusModel({
    required this.id,
    required this.name,
    required this.code,
    this.stepOrder = 1,
    this.colorHex,
    this.badgeVariant,
    this.description,
    this.isActive = true,
  });

  factory MasterOrderStatusModel.fromJson(Map<String, dynamic> json) {
    return MasterOrderStatusModel(
      id: json['id']?.toString() ?? json['id_order_statuses']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_order_statuses']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      stepOrder: int.tryParse(json['step_order']?.toString() ?? '') ?? 1,
      colorHex: json['color_hex']?.toString(),
      badgeVariant: json['badge_variant']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}

class ServiceCategoryModel {
  final String id;
  final String name;
  final String code;
  final String? iconCode;
  final String? badgeColor;
  final String? description;
  final bool isActive;

  const ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.code,
    this.iconCode,
    this.badgeColor,
    this.description,
    this.isActive = true,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: json['id']?.toString() ?? json['id_service_categories']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_service_categories']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      iconCode: json['icon_code']?.toString(),
      badgeColor: json['badge_color']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'icon_code': iconCode,
      'badge_color': badgeColor,
      'description': description,
      'is_active': isActive,
    };
  }
}
