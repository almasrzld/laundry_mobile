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

class UnitModel {
  final String id;
  final String nameUnit;
  final String codeUnit;
  final String? symbol;
  final String? description;
  final bool isActive;

  const UnitModel({
    required this.id,
    required this.nameUnit,
    required this.codeUnit,
    this.symbol,
    this.description,
    this.isActive = true,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id']?.toString() ?? json['id_units']?.toString() ?? '',
      nameUnit: json['name_unit']?.toString() ?? '',
      codeUnit: json['code_unit']?.toString() ?? '',
      symbol: json['symbol']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_unit': nameUnit,
      'code_unit': codeUnit,
      'symbol': symbol,
      'description': description,
      'is_active': isActive,
    };
  }
}

class OutletModel {
  final String id;
  final String nameOutlet;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;

  const OutletModel({
    required this.id,
    required this.nameOutlet,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
  });

  factory OutletModel.fromJson(Map<String, dynamic> json) {
    return OutletModel(
      id: json['id']?.toString() ?? json['id_outlets']?.toString() ?? '',
      nameOutlet: json['name_outlet']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_outlet': nameOutlet,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
    };
  }
}

class OngkirModel {
  final String id;
  final String outletsId;
  final String unitsId;
  final String nameOngkir;
  final String codeOngkir;
  final double freeRadius;
  final double baseRadius;
  final int basePrice;
  final double stepRadius;
  final int stepPrice;
  final double maxRadius;
  final String? outletName;
  final String? outletAddress;
  final double? outletLatitude;
  final double? outletLongitude;
  final String? outletPhone;
  final String? unitName;
  final String? unitCode;
  final String? unitSymbol;

  const OngkirModel({
    required this.id,
    required this.outletsId,
    required this.unitsId,
    required this.nameOngkir,
    required this.codeOngkir,
    required this.freeRadius,
    required this.baseRadius,
    required this.basePrice,
    required this.stepRadius,
    required this.stepPrice,
    required this.maxRadius,
    this.outletName,
    this.outletAddress,
    this.outletLatitude,
    this.outletLongitude,
    this.outletPhone,
    this.unitName,
    this.unitCode,
    this.unitSymbol,
  });

  factory OngkirModel.fromJson(Map<String, dynamic> json) {
    return OngkirModel(
      id: json['id']?.toString() ?? json['id_ongkirs']?.toString() ?? '',
      outletsId: json['outlets_id']?.toString() ?? json['outlet_id']?.toString() ?? '',
      unitsId: json['units_id']?.toString() ?? json['unit_id']?.toString() ?? '',
      nameOngkir: json['name_ongkir']?.toString() ?? '',
      codeOngkir: json['code_ongkir']?.toString() ?? '',
      freeRadius: (json['free_radius'] as num?)?.toDouble() ?? double.tryParse(json['free_radius']?.toString() ?? '') ?? 0.0,
      baseRadius: (json['base_radius'] as num?)?.toDouble() ?? double.tryParse(json['base_radius']?.toString() ?? '') ?? 0.0,
      basePrice: (json['base_price'] as num?)?.toInt() ?? int.tryParse(json['base_price']?.toString() ?? '') ?? 0,
      stepRadius: (json['step_radius'] as num?)?.toDouble() ?? double.tryParse(json['step_radius']?.toString() ?? '') ?? 0.0,
      stepPrice: (json['step_price'] as num?)?.toInt() ?? int.tryParse(json['step_price']?.toString() ?? '') ?? 0,
      maxRadius: (json['max_radius'] as num?)?.toDouble() ?? double.tryParse(json['max_radius']?.toString() ?? '') ?? 0.0,
      outletName: json['outlet_name']?.toString(),
      outletAddress: json['outlet_address']?.toString(),
      outletLatitude: (json['outlet_latitude'] as num?)?.toDouble(),
      outletLongitude: (json['outlet_longitude'] as num?)?.toDouble(),
      outletPhone: json['outlet_phone']?.toString(),
      unitName: json['unit_name']?.toString(),
      unitCode: json['unit_code']?.toString(),
      unitSymbol: json['unit_symbol']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlets_id': outletsId,
      'units_id': unitsId,
      'name_ongkir': nameOngkir,
      'code_ongkir': codeOngkir,
      'free_radius': freeRadius,
      'base_radius': baseRadius,
      'base_price': basePrice,
      'step_radius': stepRadius,
      'step_price': stepPrice,
      'max_radius': maxRadius,
      'outlet_name': outletName,
      'outlet_address': outletAddress,
      'outlet_latitude': outletLatitude,
      'outlet_longitude': outletLongitude,
      'outlet_phone': outletPhone,
      'unit_name': unitName,
      'unit_code': unitCode,
      'unit_symbol': unitSymbol,
    };
  }
}

class CalculateOngkirResultModel {
  final double distance;
  final double distanceKm;
  final int priceOngkir;
  final bool isFree;
  final bool isDeliverable;
  final String message;
  final String tierLabel;
  final UnitModel? unit;
  final OutletModel? outlet;

  const CalculateOngkirResultModel({
    required this.distance,
    required this.distanceKm,
    required this.priceOngkir,
    required this.isFree,
    required this.isDeliverable,
    required this.message,
    required this.tierLabel,
    this.unit,
    this.outlet,
  });

  factory CalculateOngkirResultModel.fromJson(Map<String, dynamic> json) {
    return CalculateOngkirResultModel(
      distance: (json['distance'] as num?)?.toDouble() ?? (json['distance_km'] as num?)?.toDouble() ?? double.tryParse(json['distance']?.toString() ?? json['distance_km']?.toString() ?? '') ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? double.tryParse(json['distance_km']?.toString() ?? '') ?? 0.0,
      priceOngkir: (json['price_ongkir'] as num?)?.toInt() ?? int.tryParse(json['price_ongkir']?.toString() ?? '') ?? 0,
      isFree: json['is_free'] == true || json['is_free'] == 1,
      isDeliverable: json['is_deliverable'] != false,
      message: json['message']?.toString() ?? '',
      tierLabel: json['tier_label']?.toString() ?? '',
      unit: json['unit'] != null ? UnitModel.fromJson(json['unit'] as Map<String, dynamic>) : null,
      outlet: json['outlet'] != null ? OutletModel.fromJson(json['outlet'] as Map<String, dynamic>) : null,
    );
  }
}




