import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_endpoints.dart';
import '../services/location_service.dart';
import '../services/session_manager.dart';
import '../services/session_service.dart';
import 'api_exceptions.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient({http.Client? client}) {
    if (client != null) {
      _instance._client = client;
    }
    return _instance;
  }

  ApiClient._internal() : _client = http.Client();

  http.Client _client;
  String? _authToken;

  String get baseUrl => ApiEndpoints.baseUrl;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  String? get authToken => _authToken;

  Future<void> _ensureToken() async {
    if (_authToken == null || _authToken!.isEmpty) {
      _authToken = await SessionService.getToken();
    }
  }

  Future<Map<String, String>> _headers() async {
    await _ensureToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-platform': 'mobile',
      'x-app-platform': 'mobile',
      'User-Agent': 'AlmasLaundryApp/1.0 (Mobile; Flutter)',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    // Lampirkan koordinat GPS real-time jika tersedia di HP
    final pos = LocationService.lastKnownPosition;
    if (pos != null) {
      headers['x-latitude'] = pos.latitude.toString();
      headers['x-longitude'] = pos.longitude.toString();
      headers['x-client-location'] = 'GPS (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
      final headers = await _headers();
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw ServerException('Layanan tidak merespons.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan koneksi: $e');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _headers();
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan request: $e');
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _headers();
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan request: $e');
    }
  }

  Future<dynamic> patch(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _headers();
      final response = await _client
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan request: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _headers();
      final response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan request: $e');
    }
  }

  Future<dynamic> uploadMultipart(
    String endpoint, {
    required String fieldName,
    required List<int> fileBytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      await _ensureToken();
      final request = http.MultipartRequest('POST', uri);

      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.headers['Accept'] = 'application/json';
      request.headers['x-platform'] = 'mobile';
      request.headers['User-Agent'] = 'AlmasLaundryApp/1.0 (Mobile; Flutter)';

      final pos = LocationService.lastKnownPosition;
      if (pos != null) {
        request.headers['x-latitude'] = pos.latitude.toString();
        request.headers['x-longitude'] = pos.longitude.toString();
        request.headers['x-client-location'] = 'GPS (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      MediaType? contentType;
      final lowerName = filename.toLowerCase();
      if (lowerName.endsWith('.png')) {
        contentType = MediaType('image', 'png');
      } else if (lowerName.endsWith('.webp')) {
        contentType = MediaType('image', 'webp');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: filename,
          contentType: contentType,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan saat mengunggah file: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Parse JSON body if present
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return body;
    }

    // Extract error details from backend response
    String message = 'Terjadi kesalahan ($statusCode)';
    String? errorCode;
    Map<String, dynamic>? errorPayload;

    if (body is Map<String, dynamic>) {
      if (body['message'] != null) {
        message = body['message'].toString();
      }
      if (body['error'] is Map<String, dynamic>) {
        errorPayload = body['error'] as Map<String, dynamic>;
        errorCode = errorPayload['code']?.toString();
      }
    }

    if (statusCode == 401) {
      clearAuthToken();
      final expiredMsg = (errorCode == 'CONCURRENT_LOGIN' || message.contains('perangkat lain'))
          ? 'Sesi Anda telah berakhir karena akun Anda telah masuk di perangkat lain. Silakan masuk kembali.'
          : 'Sesi Anda telah berakhir atau tidak valid di server. Silakan masuk kembali.';
      SessionManager.handleSessionExpired(
        message: expiredMsg,
      );
      throw UnauthorizedException(message, errorPayload);
    } else if (statusCode == 403 || statusCode == 429) {
      throw ApiException(
        message,
        statusCode: statusCode,
        errorCode: errorCode,
        errorPayload: errorPayload,
      );
    } else if (statusCode >= 500) {
      throw ServerException(message, statusCode);
    } else {
      throw ApiException(
        message,
        statusCode: statusCode,
        errorCode: errorCode,
        errorPayload: errorPayload,
      );
    }
  }
}
