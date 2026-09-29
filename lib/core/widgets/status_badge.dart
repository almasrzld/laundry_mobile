import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_colors.dart';

enum OrderStatusType {
  waitingPickup,
  pickedUp,
  washing,
  ironing,
  delivering,
  completed,
  cancelled;

  String toApiString() {
    switch (this) {
      case OrderStatusType.waitingPickup:
        return 'menunggu-penjemputan';
      case OrderStatusType.pickedUp:
        return 'pesanan-dijemput';
      case OrderStatusType.washing:
        return 'proses-cuci';
      case OrderStatusType.ironing:
        return 'proses-setrika';
      case OrderStatusType.delivering:
        return 'dalam-pengantaran';
      case OrderStatusType.completed:
        return 'pesanan-selesai';
      case OrderStatusType.cancelled:
        return 'dibatalkan';
    }
  }

  static OrderStatusType fromApiString(String status) {
    final s = status.toLowerCase().trim();
    if (s.contains('pickup') || s.contains('jemputan') || s.contains('waiting')) {
      if (s.contains('dijemput') || s.contains('picked')) {
        return OrderStatusType.pickedUp;
      }
      return OrderStatusType.waitingPickup;
    }
    if (s.contains('dijemput') || s.contains('picked_up')) {
      return OrderStatusType.pickedUp;
    }
    if (s.contains('cuci') || s.contains('wash')) {
      return OrderStatusType.washing;
    }
    if (s.contains('setrika') || s.contains('iron')) {
      return OrderStatusType.ironing;
    }
    if (s.contains('antar') || s.contains('deliver') || s.contains('kirim')) {
      return OrderStatusType.delivering;
    }
    if (s.contains('selesai') || s.contains('completed') || s.contains('done')) {
      return OrderStatusType.completed;
    }
    if (s.contains('batal') || s.contains('cancel')) {
      return OrderStatusType.cancelled;
    }
    return OrderStatusType.waitingPickup;
  }
}

class StatusBadge extends StatelessWidget {
  final OrderStatusType status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case OrderStatusType.waitingPickup:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = customLabel ?? 'Menunggu Pickup';
        icon = LucideIcons.clock;
        break;
      case OrderStatusType.pickedUp:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = customLabel ?? 'Dijemput Kurir';
        icon = LucideIcons.bike;
        break;
      case OrderStatusType.washing:
        bg = const Color(0xFFE0F2FE);
        fg = AppColors.primary;
        label = customLabel ?? 'Sedang Dicuci';
        icon = LucideIcons.washingMachine;
        break;
      case OrderStatusType.ironing:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = customLabel ?? 'Disetrika Uap';
        icon = LucideIcons.sparkles;
        break;
      case OrderStatusType.delivering:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        label = customLabel ?? 'Diantar Kurir';
        icon = LucideIcons.truck;
        break;
      case OrderStatusType.completed:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        label = customLabel ?? 'Selesai';
        icon = LucideIcons.checkCircle2;
        break;
      case OrderStatusType.cancelled:
        bg = const Color(0xFFFFE4E6);
        fg = const Color(0xFFE11D48);
        label = customLabel ?? 'Dibatalkan';
        icon = LucideIcons.xCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withAlpha(40), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
