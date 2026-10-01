import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/services/session_service.dart';
import '../models/promo_model.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';

abstract class IUserRepository {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile(UserModel user);
  Future<List<AddressModel>> getAddresses();
  Future<AddressModel> addAddress({
    required String label,
    required String fullAddress,
    String note = '',
    bool isDefault = false,
  });
  Future<void> updateAddress({
    required String id,
    required String label,
    required String fullAddress,
    String note = '',
    bool isDefault = false,
  });
  Future<void> deleteAddress(String id);
  Future<List<PointHistoryModel>> getPointHistories();
  Future<Map<String, dynamic>> redeemPoints({
    required int points,
    String? code,
    String? title,
    String? subtitle,
    String? description,
    int? discountAmount,
    int? minOrderAmount,
    String? promosId,
  });
  Future<List<PromoModel>> getUserVouchers({bool activeOnly = false});
  Future<PromoModel> verifyVoucher(String code);
  Future<List<WalletTransactionModel>> getWalletTransactions({int limit = 50});
}

class UserRepository implements IUserRepository {
  final ApiClient _apiClient;
  UserModel? _cachedUser;

  UserRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.userProfile);
      if (response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        _cachedUser = UserModel.fromJson(data as Map<String, dynamic>);
        final token = await SessionService.getToken();
        if (token != null && _cachedUser != null) {
          await SessionService.saveSession(token: token, user: _cachedUser!);
        }
        return _cachedUser!;
      }
    } catch (_) {}

    final saved = await SessionService.getUser();
    if (saved != null) {
      _cachedUser = saved;
      return saved;
    }

    _cachedUser ??= UserModel.empty;
    return _cachedUser!;
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    final response = await _apiClient.put(
      ApiEndpoints.userProfile,
      body: {
        'name': user.name,
        'phone': user.phone,
      },
    );
    if (response is Map<String, dynamic> && response['data'] != null) {
      _cachedUser = UserModel.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      _cachedUser = user;
    }
    final token = await SessionService.getToken();
    if (token != null && _cachedUser != null) {
      await SessionService.saveSession(token: token, user: _cachedUser!);
    }
    return _cachedUser!;
  }

  @override
  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiClient.get(ApiEndpoints.userAddresses);
    if (response is List) {
      return response.map((e) => AddressModel.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String fullAddress,
    String note = '',
    bool isDefault = false,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.userAddresses,
      body: {
        'label': label,
        'full_address': fullAddress,
        'note': note,
        'is_default': isDefault,
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      return AddressModel.fromJson(data as Map<String, dynamic>);
    }

    throw ApiException('Gagal menambahkan alamat');
  }

  @override
  Future<void> updateAddress({
    required String id,
    required String label,
    required String fullAddress,
    String note = '',
    bool isDefault = false,
  }) async {
    await _apiClient.put(
      '${ApiEndpoints.userAddresses}/$id',
      body: {
        'label': label,
        'full_address': fullAddress,
        'note': note,
        'is_default': isDefault,
      },
    );
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _apiClient.delete('${ApiEndpoints.userAddresses}/$id');
  }

  @override
  Future<List<PointHistoryModel>> getPointHistories() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.userPointsHistory);
      List<PointHistoryModel> list = [];
      if (response is List) {
        list = response.map((item) => PointHistoryModel.fromJson(item as Map<String, dynamic>)).toList();
      } else if (response is Map && response['data'] is List) {
        list = (response['data'] as List)
            .map((item) => PointHistoryModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> redeemPoints({
    required int points,
    String? code,
    String? title,
    String? subtitle,
    String? description,
    int? discountAmount,
    int? minOrderAmount,
    String? promosId,
  }) async {
    final body = <String, dynamic>{'points': points};
    if (code != null) {
      body['code'] = code;
      body['code_voucher'] = code;
    }
    if (title != null) body['title'] = title;
    if (subtitle != null) body['subtitle'] = subtitle;
    if (description != null) body['description'] = description;
    if (discountAmount != null) body['discount_amount'] = discountAmount;
    if (minOrderAmount != null) body['min_order_amount'] = minOrderAmount;
    if (promosId != null) body['promos_id'] = promosId;

    final response = await _apiClient.post(
      ApiEndpoints.userPointsRedeem,
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'success': true};
  }

  @override
  Future<List<PromoModel>> getUserVouchers({bool activeOnly = false}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.userVouchers,
        queryParams: activeOnly ? {'active_only': 'true'} : null,
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
    } catch (_) {
      return [];
    }
  }

  @override
  Future<PromoModel> verifyVoucher(String code) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyVoucher,
      body: {'code': code.trim().toUpperCase()},
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      return PromoModel.fromJson(data as Map<String, dynamic>);
    }

    throw ApiException('Kode voucher tidak valid atau belum Anda tukarkan.');
  }

  @override
  Future<List<WalletTransactionModel>> getWalletTransactions({int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.userWalletTransactions,
        queryParams: {'limit': limit.toString()},
      );
      List<WalletTransactionModel> list = [];
      if (response is List) {
        list = response.map((item) => WalletTransactionModel.fromJson(item as Map<String, dynamic>)).toList();
      } else if (response is Map && response['data'] is List) {
        list = (response['data'] as List)
            .map((item) => WalletTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}

class PointHistoryModel {
  final String id;
  final int points;
  final String type; // 'earn' or 'redeem'
  final String title;
  final String description;
  final String createdAt;

  const PointHistoryModel({
    required this.id,
    required this.points,
    required this.type,
    required this.title,
    this.description = '',
    this.createdAt = '',
  });

  bool get isEarn => type == 'earn';

  factory PointHistoryModel.fromJson(Map<String, dynamic> json) {
    return PointHistoryModel(
      id: json['id']?.toString() ?? json['id_point_histories']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'earn',
      title: json['title']?.toString() ?? 'Poin Reward',
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
