import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/courier_summary_model.dart';
import '../models/master_model.dart';
import '../models/order_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/withdrawal_request_model.dart';

abstract class ICourierRepository {
  Future<CourierSummaryModel?> getCourierSummary();
  Future<List<OrderModel>> getCourierTasks({String? status});
  Future<List<MasterOrderStatusModel>> getMasterStatuses();
  Future<List<PaymentMethodModel>> getPaymentMethods();
  Future<bool> updateTaskStatus(String orderId, String newStatus);
  Future<List<WalletTransactionModel>> getCourierTransactions({String? category});
  Future<List<WithdrawalRequestModel>> getCourierWithdrawals();
  Future<Map<String, dynamic>> requestWithdrawal({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  });
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
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.paymentMethods);
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;

      if (data is List) {
        return data
            .map((item) => PaymentMethodModel.fromJson(item as Map<String, dynamic>))
            .where((pm) => pm.isActive)
            .toList();
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

  @override
  Future<List<WithdrawalRequestModel>> getCourierWithdrawals() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.courierWithdrawals);
      final data = response is Map && response['data'] != null
          ? response['data']
          : response;

      if (data is List) {
        return data
            .map((item) => WithdrawalRequestModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> requestWithdrawal({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.courierWithdrawals,
        body: {
          'amount': amount,
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
        },
      );
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

