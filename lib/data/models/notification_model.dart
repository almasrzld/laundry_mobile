class NotificationModel {
  final String id;
  final String? orderId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final String? invoiceNo;
  final String? serviceName;
  final String? orderStatus;

  NotificationModel({
    required this.id,
    this.orderId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.invoiceNo,
    this.serviceName,
    this.orderStatus,
  });

  NotificationModel copyWith({
    String? id,
    String? orderId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? invoiceNo,
    String? serviceName,
    String? orderStatus,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      serviceName: serviceName ?? this.serviceName,
      orderStatus: orderStatus ?? this.orderStatus,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? json['id_notifications'] ?? '').toString(),
      orderId: (json['order_id'] ?? json['orders_id'])?.toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      invoiceNo: json['invoice_no']?.toString(),
      serviceName: json['service_name']?.toString(),
      orderStatus: json['order_status']?.toString(),
    );
  }

  String get timeAgo {
    if (createdAt == null) return 'Baru saja';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }
}
