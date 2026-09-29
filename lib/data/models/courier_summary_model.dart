class CourierSummaryModel {
  final int totalCouriers;
  final int activeDeliveries;
  final int completedDeliveries;
  final int totalTips;
  final double averageRating;
  final int laundryPayBalance;

  const CourierSummaryModel({
    required this.totalCouriers,
    required this.activeDeliveries,
    required this.completedDeliveries,
    required this.totalTips,
    required this.averageRating,
    this.laundryPayBalance = 0,
  });

  factory CourierSummaryModel.fromJson(Map<String, dynamic> json) {
    return CourierSummaryModel(
      totalCouriers: (json['total_couriers'] as num?)?.toInt() ?? 0,
      activeDeliveries: (json['active_deliveries'] as num?)?.toInt() ?? 0,
      completedDeliveries: (json['completed_deliveries'] as num?)?.toInt() ?? 0,
      totalTips: (json['total_tips'] as num?)?.toInt() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      laundryPayBalance: (json['laundry_pay_balance'] as num?)?.toInt() ?? 0,
    );
  }
}
