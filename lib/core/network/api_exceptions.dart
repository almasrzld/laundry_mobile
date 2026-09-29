class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? errorPayload;

  ApiException(this.message, {this.statusCode, this.errorCode, this.errorPayload});

  int? get remainingSeconds {
    if (errorPayload != null && errorPayload!['remaining_seconds'] != null) {
      return (errorPayload!['remaining_seconds'] as num).toInt();
    }
    return null;
  }

  int? get lockoutStage {
    if (errorPayload != null && errorPayload!['lockout_stage'] != null) {
      return (errorPayload!['lockout_stage'] as num).toInt();
    }
    return null;
  }

  bool get isPermanentlyLocked {
    if (errorCode == 'ACCOUNT_PERMANENTLY_LOCKED') return true;
    if (errorPayload != null && errorPayload!['is_permanently_locked'] == true) return true;
    return false;
  }

  bool get isTemporarilyLocked {
    if (errorCode == 'ACCOUNT_TEMPORARILY_LOCKED') return true;
    return statusCode == 429;
  }

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.']);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([
    super.message = 'Sesi Anda telah berakhir. Silakan login kembali.',
    Map<String, dynamic>? errorPayload,
  ]) : super(statusCode: 401, errorPayload: errorPayload);
}

class ServerException extends ApiException {
  ServerException([
    super.message = 'Terjadi kesalahan pada server. Coba beberapa saat lagi.',
    int? statusCode,
  ]) : super(statusCode: statusCode ?? 500);
}
