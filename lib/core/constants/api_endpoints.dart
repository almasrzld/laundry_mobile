import '../config/app_config.dart';

class ApiEndpoints {
  // Configured dynamic base URL from AppConfig
  static String get baseUrl => AppConfig.baseUrl;
  static String get backendUrl => AppConfig.backendUrl;
  static String get frontendWebUrl => AppConfig.frontendWebUrl;
  static int get autoLogoutMinutes => AppConfig.autoLogoutMinutes;
  static Duration get autoLogoutDuration => AppConfig.autoLogoutDuration;

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String forgotPasswordCheck = '/auth/forgot-password/check';
  static const String forgotPasswordVerify = '/auth/forgot-password/verify';
  static const String forgotPasswordReset = '/auth/forgot-password/reset';

  // User Profile, Addresses, Points & Vouchers
  static const String userProfile = '/user/profile';
  static const String userChangePassword = '/user/change-password';
  static const String userAddresses = '/user/addresses';
  static const String userPointsHistory = '/user/points/history';
  static const String userPointsRedeem = '/user/points/redeem';
  static const String userVouchers = '/user/vouchers';
  static const String verifyVoucher = '/user/vouchers/verify';

  // Services Endpoints
  static const String services = '/services';
  static const String serviceCategories = '/master/service-categories';
  static String serviceDetail(String id) => '/services/$id';

  // Master Data (Perfumes, Units, Payment Methods, Order Statuses, Outlets, Ongkirs)
  static const String units = '/master/units';
  static const String perfumes = '/master/perfumes';
  static const String paymentMethods = '/master/payment-methods';
  static const String orderStatuses = '/master/order-statuses';
  static const String outlets = '/master/outlets';
  static const String ongkirs = '/master/ongkirs';
  static const String calculateOngkir = '/master/ongkirs/calculate';

  // Orders Endpoints
  static const String orders = '/orders';
  static const String activeOrders = '/orders?type=active';
  static const String orderHistory = '/orders?type=history';
  static String orderDetail(String id) => '/orders/$id';
  static const String createOrder = '/orders';
  static String orderRating(String id) => '/orders/$id/rating';

  // Promos & Vouchers
  static const String promos = '/promos';

  // Notifications Endpoints
  static const String notifications = '/notifications';
  static const String unreadNotificationCount = '/notifications/unread-count';
  static String markNotificationRead(String id) => '/notifications/$id/read';
  static const String markAllNotificationsRead = '/notifications/read-all';

  // Courier Endpoints
  static const String couriers = '/couriers';
  static const String courierSummary = '/couriers/summary';
  static const String courierTasks = '/couriers/tasks';
  static const String courierTransactions = '/couriers/transactions';
  static String courierUpdateTaskStatus(String id) => '/couriers/tasks/$id/status';

  // Wallet Transactions
  static const String userWalletTransactions = '/user/wallet/transactions';

  // Payment Gateway & Manual Proof Endpoints
  static const String uploadPaymentProof = '/payments/proof';
  static String paymentStatus(String orderId) => '/payments/status/$orderId';
  static const String createXenditPayment = '/payments/xendit/create';
  static const String createXenditQris = '/payments/xendit/create-qr';
  static const String simulateXenditPayment = '/payments/xendit/simulate';
  static String xenditPaymentStatus(String orderId) => '/payments/xendit/status/$orderId';
}
