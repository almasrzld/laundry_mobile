import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/promo_model.dart';

abstract class IPromoRepository {
  Future<List<PromoModel>> getPromos({String? category, bool? activeOnly, String? search});
}

class PromoRepository implements IPromoRepository {
  final ApiClient _apiClient;

  PromoRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<PromoModel>> getPromos({String? category, bool? activeOnly, String? search}) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (activeOnly != null) {
      queryParams['active_only'] = activeOnly ? '1' : '0';
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      ApiEndpoints.promos,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    List<PromoModel> list = [];

    if (response is List) {
      list = response.map((item) => PromoModel.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      list = (response['data'] as List)
          .map((item) => PromoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return list;
  }
}
