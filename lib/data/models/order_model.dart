import '../../core/widgets/status_badge.dart';

class OrderTimelineStepModel {
  final String title;
  final String description;
  final String time;
  final bool isCompleted;
  final bool isCurrent;
  final int stepOrder;

  const OrderTimelineStepModel({
    required this.title,
    required this.description,
    required this.time,
    this.isCompleted = false,
    this.isCurrent = false,
    this.stepOrder = 1,
  });

  factory OrderTimelineStepModel.fromJson(Map<String, dynamic> json) {
    return OrderTimelineStepModel(
      title: json['title']?.toString() ?? json['name_order_statuses']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      isCompleted: json['is_completed'] == true || json['is_completed'] == 1,
      isCurrent: json['is_current'] == true || json['is_current'] == 1,
      stepOrder: (json['step_order'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'time': time,
      'is_completed': isCompleted,
      'is_current': isCurrent,
      'step_order': stepOrder,
    };
  }
}

class OrderModel {
  final String id;
  final String invoiceNo;
  final String serviceName;
  final String serviceType;
  final DateTime orderDate;
  final DateTime estimatedCompletionDate;
  final OrderStatusType status;
  final String statusName;
  final double quantity;
  final String unit;
  final int pricePerUnit;
  final int deliveryFee;
  final int discount;
  final String pickupAddress;
  final String deliveryAddress;
  final String courierName;
  final String courierPhone;
  final String notes;
  final List<OrderTimelineStepModel> timeline;
  final int? rating;
  final String? review;
  final int? tipAmount;
  final DateTime? ratedAt;
  final String? customerName;
  final String? customerPhone;
  final String? userId;

  const OrderModel({
    required this.id,
    required this.invoiceNo,
    required this.serviceName,
    required this.serviceType,
    required this.orderDate,
    required this.estimatedCompletionDate,
    required this.status,
    this.statusName = '',
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.deliveryFee,
    required this.discount,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.courierName,
    required this.courierPhone,
    this.notes = '',
    required this.timeline,
    this.rating,
    this.review,
    this.tipAmount,
    this.ratedAt,
    this.customerName,
    this.customerPhone,
    this.userId,
  });

  bool get isRated => (rating != null && rating! > 0);
  bool get isCompleted => status == OrderStatusType.completed || statusName.toLowerCase().contains('selesai');
  bool get isKiloan => unit.toLowerCase() == 'kg' || serviceType.toLowerCase().contains('kilo');
  bool get isWaitingWeighing => isKiloan && quantity <= 0;

  int get subtotal => (quantity * pricePerUnit).round();
  int get totalAmount => subtotal + deliveryFee - discount;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawTimeline = json['timeline'];
    List<OrderTimelineStepModel> steps = [];
    if (rawTimeline is List) {
      steps = rawTimeline
          .map((item) => OrderTimelineStepModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final rawStatus = json['status_name']?.toString() ?? json['status']?.toString() ?? '';

    return OrderModel(
      id: json['id']?.toString() ?? json['id_orders']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      orderDate: json['order_date'] != null
          ? DateTime.tryParse(json['order_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedCompletionDate: json['estimated_completion_date'] != null
          ? DateTime.tryParse(json['estimated_completion_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: OrderStatusType.fromApiString(rawStatus),
      statusName: json['status_name']?.toString() ?? rawStatus,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      pricePerUnit: (json['price_per_unit'] as num?)?.toInt() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      pickupAddress: json['pickup_address']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      courierName: json['courier_name']?.toString() ?? '',
      courierPhone: json['courier_phone']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      timeline: steps,
      rating: (json['rating'] as num?)?.toInt(),
      review: json['review']?.toString(),
      tipAmount: (json['tip_amount'] as num?)?.toInt() ?? 0,
      ratedAt: json['rated_at'] != null ? DateTime.tryParse(json['rated_at'].toString()) : null,
      customerName: json['customer_name']?.toString() ?? json['user_name']?.toString(),
      customerPhone: json['customer_phone']?.toString() ?? json['user_phone']?.toString(),
      userId: json['user_id']?.toString() ?? json['users_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_no': invoiceNo,
      'service_name': serviceName,
      'service_type': serviceType,
      'order_date': orderDate.toIso8601String(),
      'estimated_completion_date': estimatedCompletionDate.toIso8601String(),
      'status': status.toApiString(),
      'quantity': quantity,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'courier_name': courierName,
      'courier_phone': courierPhone,
      'notes': notes,
      'timeline': timeline.map((step) => step.toJson()).toList(),
      'user_id': userId,
    };
  }

  OrderModel copyWith({
    String? id,
    String? invoiceNo,
    String? serviceName,
    String? serviceType,
    DateTime? orderDate,
    DateTime? estimatedCompletionDate,
    OrderStatusType? status,
    String? statusName,
    double? quantity,
    String? unit,
    int? pricePerUnit,
    int? deliveryFee,
    int? discount,
    String? pickupAddress,
    String? deliveryAddress,
    String? courierName,
    String? courierPhone,
    String? notes,
    List<OrderTimelineStepModel>? timeline,
    int? rating,
    String? review,
    int? tipAmount,
    DateTime? ratedAt,
    String? customerName,
    String? customerPhone,
    String? userId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      serviceName: serviceName ?? this.serviceName,
      serviceType: serviceType ?? this.serviceType,
      orderDate: orderDate ?? this.orderDate,
      estimatedCompletionDate: estimatedCompletionDate ?? this.estimatedCompletionDate,
      status: status ?? this.status,
      statusName: statusName ?? this.statusName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      courierName: courierName ?? this.courierName,
      courierPhone: courierPhone ?? this.courierPhone,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      tipAmount: tipAmount ?? this.tipAmount,
      ratedAt: ratedAt ?? this.ratedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      userId: userId ?? this.userId,
    );
  }
}
