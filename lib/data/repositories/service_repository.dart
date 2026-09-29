import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/master_model.dart';
import '../models/service_model.dart';

abstract class IServiceRepository {
  Future<List<ServiceModel>> getServices({
    ServiceCategoryType? category,
    String? categoryId,
    String? categoryCode,
    String? query,
  });
  Future<ServiceModel?> getServiceById(String id);
  Future<List<ServiceCategoryModel>> getCategories();
  Future<List<PerfumeModel>> getPerfumes();
  Future<List<PaymentMethodModel>> getPaymentMethods();
}

class ServiceRepository implements IServiceRepository {
  final ApiClient _apiClient;

  ServiceRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<ServiceModel>> getServices({
    ServiceCategoryType? category,
    String? categoryId,
    String? categoryCode,
    String? query,
  }) async {
    final response = await _apiClient.get(ApiEndpoints.services);
    List<ServiceModel> list = [];

    if (response is List) {
      list = response.map((item) => ServiceModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      list = (response['data'] as List)
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      list = list.where((s) => s.categoryId == categoryId || s.categoryCode == categoryId).toList();
    } else if (categoryCode != null && categoryCode.isNotEmpty && categoryCode != 'all') {
      list = list.where((s) => s.categoryCode.toLowerCase() == categoryCode.toLowerCase()).toList();
    } else if (category != null && category != ServiceCategoryType.all) {
      list = list.where((s) => s.category == category).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q) || s.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Future<List<ServiceCategoryModel>> getCategories() async {
    final response = await _apiClient.get(ApiEndpoints.serviceCategories);
    if (response is List) {
      return response.map((item) => ServiceCategoryModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => ServiceCategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<ServiceModel?> getServiceById(String id) async {
    final response = await _apiClient.get(ApiEndpoints.serviceDetail(id));
    if (response is Map) {
      final data = response['data'] ?? response;
      return ServiceModel.fromJson(data as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<List<PerfumeModel>> getPerfumes() async {
    final response = await _apiClient.get(ApiEndpoints.perfumes);
    if (response is List) {
      return response.map((item) => PerfumeModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => PerfumeModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final response = await _apiClient.get(ApiEndpoints.paymentMethods);
    if (response is List) {
      return response.map((item) => PaymentMethodModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => PaymentMethodModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
