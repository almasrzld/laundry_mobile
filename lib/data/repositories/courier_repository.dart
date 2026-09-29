import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/courier_summary_model.dart';
import '../models/master_model.dart';
import '../models/order_model.dart';
import '../models/wallet_transaction_model.dart';

abstract class ICourierRepository {
  Future<CourierSummaryModel?> getCourierSummary();
  Future<List<OrderModel>> getCourierTasks({String? status});
  Future<List<MasterOrderStatusModel>> getMasterStatuses();
  Future<bool> updateTaskStatus(String orderId, String newStatus);
  Future<List<WalletTransactionModel>> getCourierTransactions({String? category});
}

class CourierRepository implements ICourierRepository {
  final ApiClient _apiClient;

  CourierRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<CourierSummaryModel?> getCourierSummary() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.courierSummary);
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;
      if (data is Map<String, dynamic>) {
        return CourierSummaryModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<OrderModel>> getCourierTasks({String? status}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.courierTasks,
        queryParams: status != null ? {'status': status} : null,
      );
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;

      if (data is List) {
        return data
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<MasterOrderStatusModel>> getMasterStatuses() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.orderStatuses);
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;

      if (data is List) {
        return data
            .map((item) => MasterOrderStatusModel.fromJson(item as Map<String, dynamic>))
            .where((st) => st.isActive)
            .toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> updateTaskStatus(String orderId, String newStatus) async {
    try {
      await _apiClient.patch(
        ApiEndpoints.courierUpdateTaskStatus(orderId),
        {'status': newStatus},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<WalletTransactionModel>> getCourierTransactions({String? category}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.courierTransactions,
        queryParams: category != null ? {'category': category} : null,
      );
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;

      if (data is List) {
        return data
            .map((item) => WalletTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
