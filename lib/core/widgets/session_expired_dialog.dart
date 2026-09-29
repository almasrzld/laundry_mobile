import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../widgets/custom_button.dart';

class SessionExpiredDialog extends StatelessWidget {
  final String? message;
  final VoidCallback onConfirm;

  const SessionExpiredDialog({
    super.key,
    this.message,
    required this.onConfirm,
  });

  static Future<void> show(BuildContext context, {String? message, VoidCallback? onConfirm}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SessionExpiredDialog(
          message: message,
          onConfirm: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
            onConfirm?.call();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeoutMinutes = AppConfig.autoLogoutMinutes;
    final defaultMessage =
        'Sesi Anda telah berakhir karena tidak ada aktivitas selama $timeoutMinutes menit demi keamanan akun Anda. Silakan masuk kembali.';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clock/Lock Icon Header
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Icon(
                LucideIcons.clock,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Sesi Telah Berakhir',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message ?? defaultMessage,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Oke',
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
