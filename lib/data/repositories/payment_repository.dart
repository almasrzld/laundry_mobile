import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/payment_model.dart';

abstract class IPaymentRepository {
  Future<XenditPaymentResultModel> createXenditPayment(String orderId, {String? paymentMethod, String? phone});
  Future<XenditQrisPaymentModel> createXenditQrisPayment(String orderId);
  Future<XenditQrisPaymentModel> createXenditTopupQris(int amount);
  Future<PaymentProofResultModel> uploadPaymentProof(String orderId, List<int> fileBytes, String filename);
  Future<bool> simulatePayment(String orderId);
  Future<String> getPaymentStatus(String orderId);
  Future<XenditPaymentResultModel?> getPaymentDetails(String orderId);
}

class PaymentRepository implements IPaymentRepository {
  final ApiClient _apiClient;

  PaymentRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<XenditPaymentResultModel> createXenditPayment(String orderId, {String? paymentMethod, String? phone}) async {
    final response = await _apiClient.post(
      ApiEndpoints.createXenditPayment,
      body: {
        'order_id': orderId,
        ...?paymentMethod == null ? null : {'payment_method': paymentMethod},
        ...?phone == null ? null : {'phone': phone},
      },
    );

    if (response is Map) {
      final data = response['data'] ?? response;
      return XenditPaymentResultModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Format response pembayaran tidak sesuai');
  }

  @override
  Future<XenditQrisPaymentModel> createXenditQrisPayment(String orderId) async {
    return createXenditPayment(orderId, paymentMethod: 'QRIS');
  }

  @override
  Future<XenditQrisPaymentModel> createXenditTopupQris(int amount) async {
    final response = await _apiClient.post(
      ApiEndpoints.createXenditTopupQris,
      body: {'amount': amount},
    );

    if (response is Map) {
      final data = response['data'] ?? response;
      return XenditPaymentResultModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Gagal membuat pembayaran QRIS top-up');
  }

  @override
  Future<PaymentProofResultModel> uploadPaymentProof(String orderId, List<int> fileBytes, String filename) async {
    final response = await _apiClient.uploadMultipart(
      ApiEndpoints.uploadPaymentProof,
      fieldName: 'proof',
      fileBytes: fileBytes,
      filename: filename,
      fields: {'order_id': orderId},
    );

    if (response is Map) {
      final data = response['data'] ?? response;
      return PaymentProofResultModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Gagal mengunggah bukti pembayaran');
  }

  @override
  Future<bool> simulatePayment(String orderId) async {
    final response = await _apiClient.post(
      ApiEndpoints.simulateXenditPayment,
      body: {'order_id': orderId},
    );

    if (response is Map) {
      return response['success'] == true;
    }
    return true;
  }

  @override
  Future<String> getPaymentStatus(String orderId) async {
    final response = await _apiClient.get(ApiEndpoints.paymentStatus(orderId));
    if (response is Map) {
      final data = response['data'] ?? response;
      return data['status']?.toString() ?? 'UNPAID';
    }
    return 'UNPAID';
  }

  @override
  Future<XenditPaymentResultModel?> getPaymentDetails(String orderId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.paymentStatus(orderId));
      if (response is Map) {
        final data = response['data'] ?? response;
        return XenditPaymentResultModel.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
