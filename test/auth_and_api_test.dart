import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/core/constants/security_questions.dart';
import 'package:laundry_app/core/network/api_exceptions.dart';
import 'package:laundry_app/core/widgets/status_badge.dart';
import 'package:laundry_app/data/models/master_model.dart';
import 'package:laundry_app/data/models/service_model.dart';
import 'package:laundry_app/data/models/user_model.dart';

void main() {
  group('Security Questions Tests', () {
    test('Standard questions list contains 7 questions', () {
      expect(SecurityQuestions.list.length, 7);
      expect(SecurityQuestions.list.first, 'Siapa nama gadis ibu kandung Anda?');
    });
  });

  group('UserModel Serialization & Lockout Tests', () {
    test('Parse user with lockout state', () {
      final json = {
        'id': 'usr-123',
        'name': 'Salwa Customer',
        'email': 'salwa@gmail.com',
        'phone': '08123456789',
        'user_code': 'CUST-001',
        'role_code': 'customer',
        'member_tier': 'Gold Member',
        'laundry_pay_balance': 250000,
        'reward_points': 500,
        'failed_login_attempts': 2,
        'lockout_stage': 1,
        'is_permanently_locked': false,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'usr-123');
      expect(user.name, 'Salwa Customer');
      expect(user.userCode, 'CUST-001');
      expect(user.laundryPayBalance, 250000);
      expect(user.lockoutStage, 1);
      expect(user.isPermanentlyLocked, false);
    });
  });

  group('OrderStatusType Tests', () {
    test('Parse various status strings correctly', () {
      expect(OrderStatusType.fromApiString('menunggu-penjemputan'), OrderStatusType.waitingPickup);
      expect(OrderStatusType.fromApiString('pesanan-dijemput'), OrderStatusType.pickedUp);
      expect(OrderStatusType.fromApiString('proses-cuci'), OrderStatusType.washing);
      expect(OrderStatusType.fromApiString('proses-setrika'), OrderStatusType.ironing);
      expect(OrderStatusType.fromApiString('dalam-pengantaran'), OrderStatusType.delivering);
      expect(OrderStatusType.fromApiString('pesanan-selesai'), OrderStatusType.completed);
      expect(OrderStatusType.fromApiString('dibatalkan'), OrderStatusType.cancelled);
    });
  });

  group('ApiException Lockout Extraction Tests', () {
    test('Extract remaining seconds and lockout stage from error payload', () {
      final exception = ApiException(
        'Akun Anda terkunci sementara',
        statusCode: 429,
        errorCode: 'ACCOUNT_TEMPORARILY_LOCKED',
        errorPayload: {
          'remaining_seconds': 5,
          'lockout_stage': 1,
          'code': 'ACCOUNT_TEMPORARILY_LOCKED',
        },
      );

      expect(exception.isTemporarilyLocked, true);
      expect(exception.remainingSeconds, 5);
      expect(exception.lockoutStage, 1);
      expect(exception.isPermanentlyLocked, false);
    });

    test('Detect permanent lockout', () {
      final exception = ApiException(
        'Akun dinonaktifkan',
        statusCode: 403,
        errorCode: 'ACCOUNT_PERMANENTLY_LOCKED',
        errorPayload: {
          'is_permanently_locked': true,
          'code': 'ACCOUNT_PERMANENTLY_LOCKED',
        },
      );

      expect(exception.isPermanentlyLocked, true);
    });
  });

  group('ServiceModel & Master Models Tests', () {
    test('ServiceModel parse with unit and relations', () {
      final json = {
        'id': 'srv-1',
        'name_services': 'Cuci Komplit Reguler',
        'price': 8000,
        'unit': 'kg',
        'duration': '2 Hari',
        'icon_code': 'wash',
        'category': 'kiloan',
        'is_popular': 1,
      };

      final srv = ServiceModel.fromJson(json);
      expect(srv.name, 'Cuci Komplit Reguler');
      expect(srv.price, 8000);
      expect(srv.category, ServiceCategoryType.kiloan);
      expect(srv.isPopular, true);
    });

    test('ServiceCategoryModel parse', () {
      final json = {
        'id': 'cat-1',
        'name_service_categories': 'Sepatu & Tas Premium',
        'code': 'sepatu_tas',
        'icon_code': 'sparkles',
        'is_active': 1,
      };

      final cat = ServiceCategoryModel.fromJson(json);
      expect(cat.id, 'cat-1');
      expect(cat.name, 'Sepatu & Tas Premium');
      expect(cat.code, 'sepatu_tas');
      expect(cat.iconCode, 'sparkles');
      expect(cat.isActive, true);
    });

    test('PerfumeModel parse', () {
      final json = {
        'id': '1',
        'name_perfumes': 'Original Fresh',
        'description': 'Wangi segar bersih',
        'is_default': 1,
      };

      final perfume = PerfumeModel.fromJson(json);
      expect(perfume.name, 'Original Fresh');
      expect(perfume.isDefault, true);
    });
  });
}
