import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/widgets/status_badge.dart';
import '../models/order_model.dart';

abstract class IOrderRepository {
  Future<List<OrderModel>> getOrders({bool? onlyActive});
  Future<OrderModel?> getOrderById(String id);
  Future<OrderModel> createOrder({
    required String serviceName,
    required String serviceType,
    required double quantity,
    required String unit,
    required int pricePerUnit,
    required String pickupAddress,
    required String deliveryAddress,
    int deliveryFee = 0,
    int discount = 0,
    String? voucherCode,
    int pointsRedeemed = 0,
    String? paymentMethod,
    String? paymentMethodCode,
    String notes = '',
  });
  Future<bool> submitRating(
    String id, {
    required int rating,
    String? review,
    int? tipAmount,
  });
}

class OrderRepository implements IOrderRepository {
  final ApiClient _apiClient;

  OrderRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<OrderModel>> getOrders({bool? onlyActive}) async {
    final endpoint = onlyActive == true
        ? ApiEndpoints.activeOrders
        : (onlyActive == false ? ApiEndpoints.orderHistory : ApiEndpoints.orders);

    final response = await _apiClient.get(endpoint);
    List<OrderModel> orders = [];

    if (response is List) {
      orders = response.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      orders = (response['data'] as List)
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (onlyActive == true) {
      return orders
          .where((o) => o.status != OrderStatusType.completed && o.status != OrderStatusType.cancelled)
          .toList();
    } else if (onlyActive == false) {
      return orders
          .where((o) => o.status == OrderStatusType.completed || o.status == OrderStatusType.cancelled)
          .toList();
    }
    return orders;
  }

  @override
  Future<OrderModel?> getOrderById(String id) async {
    final response = await _apiClient.get(ApiEndpoints.orderDetail(id));
    if (response is Map) {
      final data = response['data'] ?? response;
      return OrderModel.fromJson(data as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<OrderModel> createOrder({
    required String serviceName,
    required String serviceType,
    required double quantity,
    required String unit,
    required int pricePerUnit,
    required String pickupAddress,
    required String deliveryAddress,
    int deliveryFee = 0,
    int discount = 0,
    String? voucherCode,
    int pointsRedeemed = 0,
    String? paymentMethod,
    String? paymentMethodCode,
    String notes = '',
  }) async {
    final body = {
      'service_name': serviceName,
      'service_type': serviceType,
      'quantity': quantity,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'delivery_fee': deliveryFee,
      'discount': discount,
      if (voucherCode != null && voucherCode.trim().isNotEmpty) 'voucher_code': voucherCode.trim(),
      if (pointsRedeemed > 0) 'points_redeemed': pointsRedeemed,
      if (paymentMethod != null && paymentMethod.trim().isNotEmpty) 'payment_method': paymentMethod.trim(),
      if (paymentMethodCode != null && paymentMethodCode.trim().isNotEmpty) 'payment_method_code': paymentMethodCode.trim(),
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'notes': notes,
    };

    final response = await _apiClient.post(
      ApiEndpoints.createOrder,
      body: body,
    );

    if (response is Map) {
      final data = response['data'] ?? response;
      return OrderModel.fromJson(data as Map<String, dynamic>);
    }

    throw ApiException('Gagal membuat pesanan laundry');
  }

  @override
  Future<bool> submitRating(
    String id, {
    required int rating,
    String? review,
    int? tipAmount,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.orderRating(id),
        body: {
          'rating': rating,
          if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
          'tip_amount': tipAmount ?? 0,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
