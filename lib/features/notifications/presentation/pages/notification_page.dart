import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_realtime_service.dart';
import '../../../../data/models/notification_model.dart';
import '../../../orders/presentation/pages/order_detail_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationRealtimeService _realtimeService = NotificationRealtimeService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_realtimeService.notificationsNotifier.value.isEmpty) {
      _isLoading = true;
    }
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    try {
      await _realtimeService.refresh();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    await _realtimeService.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai telah dibaca'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleItemTap(NotificationModel notif) async {
    if (!notif.isRead) {
      _realtimeService.markAsRead(notif.id);
    }

    if (notif.orderId != null && notif.orderId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(orderId: notif.orderId!),
        ),
      );
    }
  }

  Widget _buildIcon(String type) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'order_created':
        iconData = LucideIcons.shoppingBag;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withAlpha(25);
        break;
      case 'courier_assigned':
        iconData = LucideIcons.truck;
        iconColor = Colors.teal;
        bgColor = Colors.teal.withAlpha(25);
        break;
      case 'order_ready':
        iconData = LucideIcons.sparkles;
        iconColor = Colors.amber.shade800;
        bgColor = Colors.amber.withAlpha(25);
        break;
      case 'order_completed':
        iconData = LucideIcons.checkCircle2;
        iconColor = Colors.green;
        bgColor = Colors.green.withAlpha(25);
        break;
      case 'order_processing':
      case 'order_status_updated':
        iconData = LucideIcons.waves;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withAlpha(25);
        break;
      default:
        iconData = LucideIcons.bell;
        iconColor = AppColors.textSecondary;
        bgColor = AppColors.surfaceVariant;
        break;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NotificationModel>>(
      valueListenable: _realtimeService.notificationsNotifier,
      builder: (context, notifications, child) {
        final hasUnread = notifications.any((n) => !n.isRead);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Notifikasi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (hasUnread)
                TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(LucideIcons.checkCheck, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Baca Semua',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshNotifications,
                  color: AppColors.primary,
                  child: notifications.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.bellOff,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum Ada Notifikasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pemberitahuan status pesanan dan penugasan kurir akan ditampilkan secara real-time di sini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            return InkWell(
                              onTap: () => _handleItemTap(notif),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: notif.isRead
                                      ? Colors.white
                                      : AppColors.primary.withAlpha(10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: notif.isRead
                                        ? AppColors.border
                                        : AppColors.primary.withAlpha(50),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildIcon(notif.type),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: notif.isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                notif.timeAgo,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.message,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.3,
                                            ),
                                          ),
                                          if (notif.invoiceNo != null &&
                                              notif.invoiceNo!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#${notif.invoiceNo}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!notif.isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}
