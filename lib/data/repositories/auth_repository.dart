import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/services/session_service.dart';
import '../models/user_model.dart';

abstract class IAuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    String? password,
  });
  Future<UserModel?> getMe();
  Future<Map<String, dynamic>> initForgotPassword(String identifier);
  Future<String> verifySecurityQuestions({
    required String sessionToken,
    required String answer1,
    required String answer2,
  });
  Future<String> resetPasswordWithToken({
    required String resetToken,
    required String newPassword,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    String? question1,
    String? answer1,
    String? question2,
    String? answer2,
  });
  Future<void> logout();
}

class AuthRepository implements IAuthRepository {
  final ApiClient _apiClient;

  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<UserModel> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      final token = data['token']?.toString() ?? '';
      final userMap = (data['user'] ?? data) as Map<String, dynamic>;
      final user = UserModel.fromJson(userMap);

      if (token.isNotEmpty) {
        _apiClient.setAuthToken(token);
        await SessionService.saveSession(token: token, user: user);
      }
      return user;
    }

    throw Exception('Gagal memproses respon login');
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    String? password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      final token = data['token']?.toString() ?? '';
      final userMap = (data['user'] ?? data) as Map<String, dynamic>;
      final user = UserModel.fromJson(userMap);

      if (token.isNotEmpty) {
        _apiClient.setAuthToken(token);
        await SessionService.saveSession(token: token, user: user);
      }
      return user;
    }

    throw Exception('Gagal melakukan pendaftaran');
  }

  @override
  Future<UserModel?> getMe() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      if (response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        final user = UserModel.fromJson(data as Map<String, dynamic>);
        final token = await SessionService.getToken();
        if (token != null) {
          await SessionService.saveSession(token: token, user: user);
        }
        return user;
      }
    } catch (_) {}
    return await SessionService.getUser();
  }

  @override
  Future<Map<String, dynamic>> initForgotPassword(String identifier) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPasswordCheck,
      body: {'identifier': identifier.trim()},
    );

    if (response is Map<String, dynamic>) {
      return (response['data'] ?? response) as Map<String, dynamic>;
    }
    throw Exception('Gagal memeriksa data akun');
  }

  @override
  Future<String> verifySecurityQuestions({
    required String sessionToken,
    required String answer1,
    required String answer2,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPasswordVerify,
      body: {
        'session_token': sessionToken,
        'answer_1': answer1.trim(),
        'answer_2': answer2.trim(),
      },
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      return data['reset_token']?.toString() ?? '';
    }
    throw Exception('Gagal memverifikasi jawaban pertanyaan keamanan');
  }

  @override
  Future<String> resetPasswordWithToken({
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPasswordReset,
      body: {
        'reset_token': resetToken,
        'new_password': newPassword,
      },
    );

    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Kata sandi berhasil direset';
    }
    return 'Kata sandi berhasil direset';
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    String? question1,
    String? answer1,
    String? question2,
    String? answer2,
  }) async {
    final body = <String, dynamic>{
      'old_password': oldPassword,
      'new_password': newPassword,
    };
    if (question1 != null && answer1 != null && question2 != null && answer2 != null) {
      body['question_1'] = question1;
      body['answer_1'] = answer1;
      body['question_2'] = question2;
      body['answer_2'] = answer2;
    }

    await _apiClient.put(ApiEndpoints.userChangePassword, body: body);
  }

  @override
  Future<void> logout() async {
    _apiClient.clearAuthToken();
    await SessionService.clearSession();
  }
}
