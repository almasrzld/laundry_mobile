import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_realtime_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/models/promo_model.dart';
import '../../../../data/models/service_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../data/repositories/promo_repository.dart';
import '../../../../data/repositories/service_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../orders/presentation/pages/order_detail_page.dart';
import '../../../notifications/presentation/pages/notification_page.dart';
import '../../../courier/presentation/pages/courier_tasks_page.dart';
import '../../../services/presentation/widgets/order_checkout_sheet.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final IOrderRepository? orderRepository;
  final IServiceRepository? serviceRepository;
  final IPromoRepository? promoRepository;
  final IUserRepository? userRepository;

  const HomePage({
    super.key,
    this.onNavigateTab,
    this.orderRepository,
    this.serviceRepository,
    this.promoRepository,
    this.userRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final IOrderRepository _orderRepository;
  late final IServiceRepository _serviceRepository;
  late final IPromoRepository _promoRepository;
  late final IUserRepository _userRepository;
  late final INotificationRepository _notificationRepository;

  UserModel _user = UserModel.empty;
  OrderModel? _activeOrder;
  List<ServiceModel> _services = [];
  List<PromoModel> _promos = [];
  bool _isLoading = true;
  StreamSubscription? _realtimeRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _serviceRepository = widget.serviceRepository ?? ServiceRepository();
    _promoRepository = widget.promoRepository ?? PromoRepository();
    _userRepository = widget.userRepository ?? UserRepository();
    _notificationRepository = NotificationRepository();
    
    // 1. Immediately hydrate with cached session user to prevent empty UI / greeting flickering
    _initSessionUser();

    // 2. Fetch fresh dashboard data from API
    _loadDashboardData();

    // 3. Listen to real-time sync events (profile update, new address, order status updates, etc.)
    _realtimeRefreshSubscription = NotificationRealtimeService.instance.onRefreshRequired.listen((_) {
      if (mounted) {
        _loadDashboardData(isSilent: true);
      }
    });
  }

  Future<void> _initSessionUser() async {
    try {
      final cached = await SessionService.getUser();
      if (cached != null && mounted) {
        setState(() {
          _user = cached;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool isSilent = false}) async {
    if (!isSilent && _user == UserModel.empty) {
      setState(() => _isLoading = true);
    }

    UserModel? fetchedUser;
    List<OrderModel>? fetchedActiveOrders;
    List<ServiceModel>? fetchedServices;
    List<PromoModel>? fetchedPromos;
    int? fetchedUnreadCount;

    try {
      fetchedUser = await _userRepository.getProfile();
    } catch (_) {}

    try {
      fetchedActiveOrders = await _orderRepository.getOrders(onlyActive: true);
    } catch (_) {}

    try {
      fetchedServices = await _serviceRepository.getServices();
    } catch (_) {}

    try {
      fetchedPromos = await _promoRepository.getPromos();
    } catch (_) {}

    try {
      fetchedUnreadCount = await _notificationRepository.getUnreadCount();
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (fetchedUser != null && (fetchedUser.name.isNotEmpty || fetchedUser.addresses.isNotEmpty)) {
          _user = fetchedUser;
        }
        if (fetchedActiveOrders != null) {
          _activeOrder = fetchedActiveOrders.isNotEmpty ? fetchedActiveOrders.first : null;
        }
        if (fetchedServices != null && fetchedServices.isNotEmpty) {
          _services = fetchedServices.take(6).toList();
        }
        if (fetchedPromos != null && fetchedPromos.isNotEmpty) {
          _promos = fetchedPromos.where((p) => p.isValidPeriod).toList();
        }
        _isLoading = false;
      });
      if (fetchedUnreadCount != null) {
        NotificationRealtimeService.instance.unreadCountNotifier.value = fetchedUnreadCount;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canViewOrders = _user.hasPermission('mobile.pesanan');
    final canViewPromo = _user.hasPermission('mobile.promo');
    final canViewServices = _user.hasPermission('mobile.pesan-laundry');
    final canViewCourier = _user.hasPermission('mobile.tugas-kurir');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: CustomScrollView(
                  slivers: [
                    // Top App Bar / Greeting
                    SliverToBoxAdapter(
                      child: _buildHeader(context),
                    ),

                    // Courier Quick Task Banner (if role has courier access)
                    if (canViewCourier)
                      SliverToBoxAdapter(
                        child: _buildCourierTaskBanner(context),
                      ),

                    // Active Order Snapshot
                    if (canViewOrders && _activeOrder != null)
                      SliverToBoxAdapter(
                        child: _buildActiveOrderCard(context, _activeOrder!),
                      ),

                    // Promo Banner Carousel
                    if (canViewPromo && _promos.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildPromoBanners(context),
                      ),

                    // Service Categories
                    if (canViewServices)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: 'Layanan Kami',
                              subtitle: 'Pilih layanan sesuai kebutuhan pakaian Anda',
                              actionText: AppStrings.viewAll,
                              onActionTap: () => widget.onNavigateTab?.call(1),
                            ),
                            _buildServiceGrid(context),
                          ],
                        ),
                      ),

                    // Why Choose Us
                    SliverToBoxAdapter(
                      child: _buildWhyChooseUs(),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final rawName = _user.name.trim();
    final displayName = rawName.isNotEmpty
        ? rawName
        : (_user.email.isNotEmpty && _user.email.contains('@')
            ? _user.email.split('@').first
            : '');

    final greetingName = displayName.isNotEmpty ? displayName.split(' ').first : 'Pelanggan';

    final initials = displayName.isNotEmpty
        ? displayName.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join()
        : 'P';

    final defaultAddr = _user.defaultAddress?.fullAddress.trim();
    final firstAddr = _user.addresses.isNotEmpty ? _user.addresses.first.fullAddress.trim() : null;
    final addressText = (defaultAddr != null && defaultAddr.isNotEmpty)
        ? defaultAddr
        : ((firstAddr != null && firstAddr.isNotEmpty)
            ? firstAddr
            : 'Belum ada alamat tersimpan');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User Avatar (Solid Color)
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Greeting & Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Halo, $greetingName! 👋',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_user.userCode != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${_user.userCode}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showLocationPickerSheet(context),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              addressText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Notification Icon with Real-Time Badge (conditional on mobile.notifikasi)
              if (_user.hasPermission('mobile.notifikasi'))
                ValueListenableBuilder<int>(
                  valueListenable: NotificationRealtimeService.instance.unreadCountNotifier,
                  builder: (context, unreadCount, child) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.bell, color: AppColors.textPrimary, size: 20),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationPage(),
                              ),
                            );
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance & Points Card (Solid Flat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.wallet, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LaundryPay', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(
                              CurrencyFormatter.formatRupiah(_user.laundryPayBalance),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.star, color: Color(0xFFD97706), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Poin Reward', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(
                              '${_user.rewardPoints} Pts',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourierTaskBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.truck, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Akses Cepat Tugas Kurir',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelola pickup, delivery, dan cek tips harian Anda',
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CourierTasksPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Buka', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLocationPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        bool isDetecting = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Lokasi Penjemputan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetCtx),
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Button: Gunakan Lokasi Saat Ini (GPS)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isDetecting
                          ? null
                          : () async {
                              setSheetState(() => isDetecting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await LocationService.getCurrentLocationWithAddress(bottomSheetCtx);
                              setSheetState(() => isDetecting = false);
                              if (result != null) {
                                if (bottomSheetCtx.mounted) {
                                  Navigator.pop(bottomSheetCtx);
                                }
                                try {
                                  final existingCurrentLoc = _user.addresses.where(
                                    (a) => a.label.toLowerCase() == 'lokasi terkini',
                                  ).firstOrNull;

                                  if (existingCurrentLoc != null) {
                                    await _userRepository.updateAddress(
                                      id: existingCurrentLoc.id,
                                      label: result.suggestedLabel,
                                      fullAddress: result.fullAddress,
                                      isDefault: true,
                                    );
                                  } else {
                                    await _userRepository.addAddress(
                                      label: result.suggestedLabel,
                                      fullAddress: result.fullAddress,
                                      isDefault: true,
                                    );
                                  }
                                  await _loadDashboardData();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.success,
                                        content: Text('Lokasi berhasil diatur ke ${result.fullAddress}'),
                                      ),
                                    );
                                  }
                                } catch (_) {}
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: isDetecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : const Icon(LucideIcons.locateFixed, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDetecting ? 'Mendeteksi koordinat GPS...' : 'Gunakan Lokasi Saat Ini (GPS)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Deteksi alamat penjemputan otomatis via GPS',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Saved Addresses List
                    if (_user.addresses.isNotEmpty) ...[
                      const Text(
                        'Alamat Tersimpan',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _user.addresses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final addr = _user.addresses[index];
                            final isSelected = addr.id == _user.defaultAddress?.id;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(this.context);
                                Navigator.pop(bottomSheetCtx);
                                try {
                                  await _userRepository.updateAddress(
                                    id: addr.id,
                                    label: addr.label,
                                    fullAddress: addr.fullAddress,
                                    isDefault: true,
                                  );
                                  await _loadDashboardData();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.success,
                                        content: Text('Alamat penjemputan diatur ke ${addr.label}'),
                                      ),
                                    );
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryLight.withAlpha(80) : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? LucideIcons.checkCircle2 : LucideIcons.mapPin,
                                      size: 16,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            addr.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            addr.fullAddress,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveOrderCard(BuildContext context, OrderModel order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0284C7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.droplets, color: AppColors.primary, size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pesanan Aktif',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.serviceName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${order.invoiceNo} • Estimasi selesai: ${CurrencyFormatter.formatDateShort(order.estimatedCompletionDate)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${CurrencyFormatter.formatRupiah(order.totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(order: order),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.radar, size: 14),
                label: const Text('Lacak Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 1.5,
                  shadowColor: const Color(0x330284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanners(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Promo & Diskon Hari Ini',
          subtitle: 'Gunakan kode voucher sebelum memesan laundry',
        ),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _promos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final promo = _promos[index];
              return _buildPromoCard(context, promo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard(BuildContext context, PromoModel promo) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Clipboard.setData(ClipboardData(text: promo.code));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Kode promo "${promo.code}" disalin!'),
                ],
              ),
            ),
          );
        },
        child: Container(
          width: 265,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260284C7),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(promo.icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promo.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                promo.subtitle,
                style: TextStyle(
                  color: Colors.white.withAlpha(225),
                  fontSize: 11,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withAlpha(60), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kode: ', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(
                      promo.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.copy, color: Colors.white70, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _services.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final s = _services[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              OrderCheckoutSheet.show(
                context,
                service: s,
                user: _user,
                onOrderSuccess: () {
                  _loadDashboardData(isSilent: true);
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s.icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.name.split('(').first.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatRupiah(s.price),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWhyChooseUs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keunggulan Almas Laundry (Water Care)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildFeatureRow(
            icon: LucideIcons.droplets,
            title: 'Filtrasi Air Steril & 1 Mesin 1 Pelanggan',
            subtitle: 'Menggunakan air murni terfilterasi & pakaian tidak dicampur pelanggan lain.',
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: LucideIcons.zap,
            title: 'Tepat Waktu & Bergaransi',
            subtitle: 'Layanan express sesuai estimasi atau garansi cuci gratis.',
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: LucideIcons.leaf,
            title: 'Deterjen Ramah Lingkungan',
            subtitle: 'Formula lembut melindungi serat pakaian dan tahan wangi hingga 2 minggu.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
