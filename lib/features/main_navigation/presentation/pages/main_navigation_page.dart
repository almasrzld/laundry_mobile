import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:laundry_app/core/constants/app_colors.dart';
import 'package:laundry_app/core/constants/app_strings.dart';
import 'package:laundry_app/core/services/notification_realtime_service.dart';
import 'package:laundry_app/core/services/session_service.dart';
import 'package:laundry_app/data/models/user_model.dart';
import 'package:laundry_app/features/courier/presentation/pages/courier_tasks_page.dart';
import 'package:laundry_app/features/home/presentation/pages/home_page.dart';
import 'package:laundry_app/features/notifications/presentation/pages/notification_page.dart';
import 'package:laundry_app/features/orders/presentation/pages/order_detail_page.dart';
import 'package:laundry_app/features/orders/presentation/pages/orders_page.dart';
import 'package:laundry_app/features/profile/presentation/pages/profile_page.dart';
import 'package:laundry_app/features/services/presentation/pages/services_page.dart';

class _NavTabItem {
  final String permission;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext context, void Function(int) onNavigate) builder;

  const _NavTabItem({
    required this.permission,
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  UserModel? _user;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _refreshSubscription;
  Timer? _bannerDismissTimer;

  @override
  void initState() {
    super.initState();
    _initSessionUser();

    // Start real-time SSE notification listener & background polling
    NotificationRealtimeService.instance.start();

    _notifSubscription = NotificationRealtimeService.instance.onNewNotification.listen((notif) {
      if (!mounted) return;
      _showInAppNotificationBanner(notif);
    });

    _refreshSubscription = NotificationRealtimeService.instance.onRefreshRequired.listen((_) {
      _initSessionUser();
    });
  }

  Future<void> _initSessionUser() async {
    try {
      final user = await SessionService.getUser();
      if (mounted && user != null) {
        setState(() {
          _user = user;
          final tabs = _getActiveTabs();
          if (_currentIndex >= tabs.length) {
            _currentIndex = 0;
          }
        });
      }
    } catch (_) {}
  }

  List<_NavTabItem> _getAllTabs() {
    return [
      _NavTabItem(
        permission: 'mobile.beranda',
        label: AppStrings.navHome,
        icon: LucideIcons.home,
        builder: (ctx, onNav) => HomePage(onNavigateTab: onNav),
      ),
      _NavTabItem(
        permission: 'mobile.pesan-laundry',
        label: AppStrings.navServices,
        icon: LucideIcons.shirt,
        builder: (ctx, onNav) => const ServicesPage(),
      ),
      _NavTabItem(
        permission: 'mobile.tugas-kurir',
        label: 'Tugas Kurir',
        icon: LucideIcons.truck,
        builder: (ctx, onNav) => const CourierTasksPage(),
      ),
      _NavTabItem(
        permission: 'mobile.pesanan',
        label: AppStrings.navOrders,
        icon: LucideIcons.fileText,
        builder: (ctx, onNav) => const OrdersPage(),
      ),
      _NavTabItem(
        permission: 'mobile.profil',
        label: AppStrings.navProfile,
        icon: LucideIcons.user,
        builder: (ctx, onNav) => const ProfilePage(),
      ),
    ];
  }

  List<_NavTabItem> _getActiveTabs() {
    if (_user == null) {
      return [];
    }
    final all = _getAllTabs();
    return all.where((t) => _user!.hasPermission(t.permission)).toList();
  }

  void _showInAppNotificationBanner(dynamic notif) {
    _bannerDismissTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.bellRing, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(210),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Lihat',
          textColor: const Color(0xFF38BDF8),
          onPressed: () {
            _bannerDismissTimer?.cancel();
            ScaffoldMessenger.of(context).clearSnackBars();
            if (notif.orderId != null && notif.orderId.toString().isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(orderId: notif.orderId.toString()),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationPage(),
                ),
              );
            }
          },
        ),
      ),
    );

    _bannerDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  @override
  void dispose() {
    _bannerDismissTimer?.cancel();
    _notifSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    final activeTabs = _getActiveTabs();
    if (index >= 0 && index < activeTabs.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _navigateToPermission(String permCode) {
    final activeTabs = _getActiveTabs();
    final idx = activeTabs.indexWhere((t) => t.permission == permCode);
    if (idx != -1) {
      _onTabSelected(idx);
    } else {
      if (permCode == 'mobile.pesan-laundry') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesPage()));
      } else if (permCode == 'mobile.tugas-kurir') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CourierTasksPage()));
      } else if (permCode == 'mobile.pesanan') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()));
      } else if (permCode == 'mobile.profil') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTabs = _getActiveTabs();
    final safeIndex = (_currentIndex >= activeTabs.length) ? 0 : _currentIndex;

    final currentTab = activeTabs.isNotEmpty ? activeTabs[safeIndex] : null;
    final isBeranda = currentTab?.permission == 'mobile.beranda';
    final hasPesanLaundryPerm = _user?.hasPermission('mobile.pesan-laundry') == true;

    return Scaffold(
      body: activeTabs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : IndexedStack(
              index: safeIndex,
              children: activeTabs.map((tab) => tab.builder(context, (idx) {
                // If HomePage calls onNavigateTab(1), we route to Layanan tab or target index
                if (idx == 1) {
                  _navigateToPermission('mobile.pesan-laundry');
                } else if (idx >= 0 && idx < activeTabs.length) {
                  _onTabSelected(idx);
                }
              })).toList(),
            ),
      bottomNavigationBar: activeTabs.length <= 1
          ? null
          : Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: safeIndex,
                onTap: _onTabSelected,
                type: activeTabs.length > 3 ? BottomNavigationBarType.fixed : BottomNavigationBarType.fixed,
                items: activeTabs.map((tab) {
                  return BottomNavigationBarItem(
                    icon: Icon(tab.icon, size: 22),
                    activeIcon: Icon(tab.icon, size: 22),
                    label: tab.label,
                  );
                }).toList(),
              ),
            ),
      floatingActionButton: (isBeranda && hasPesanLaundryPerm)
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToPermission('mobile.pesan-laundry'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 20),
              label: const Text(
                'Pesan Laundry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
