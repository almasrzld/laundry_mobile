import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../services/session_manager.dart';

enum ToastType {
  success,
  error,
  warning,
  info,
}

/// Utility untuk menampilkan Toast / Notifikasi mengambang di atas seluruh layer (Overlay)
/// termasuk di atas Modal Bottom Sheet dan Dialog agar tidak tertutup di belakang card.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showSuccess(BuildContext? context, String message, {Duration? duration}) {
    show(context, message: message, type: ToastType.success, duration: duration);
  }

  static void showError(BuildContext? context, String message, {Duration? duration}) {
    show(context, message: message, type: ToastType.error, duration: duration);
  }

  static void showWarning(BuildContext? context, String message, {Duration? duration}) {
    show(context, message: message, type: ToastType.warning, duration: duration);
  }

  static void showInfo(BuildContext? context, String message, {Duration? duration}) {
    show(context, message: message, type: ToastType.info, duration: duration);
  }

  static void show(
    BuildContext? context, {
    required String message,
    ToastType type = ToastType.info,
    Duration? duration,
  }) {
    // Cari overlay state (utamakan rootOverlay agar di atas modal bottom sheet & dialog)
    OverlayState? overlayState;

    if (context != null && context.mounted) {
      try {
        overlayState = Overlay.maybeOf(context, rootOverlay: true);
      } catch (_) {}
    }

    if (overlayState == null) {
      final navState = SessionManager.navigatorKey.currentState;
      if (navState != null) {
        overlayState = navState.overlay;
      }
    }

    if (overlayState == null) return;

    // Bersihkan toast sebelumnya jika masih aktif
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;

    final toastDuration = duration ?? const Duration(milliseconds: 3500);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayWidget(
        message: message,
        type: type,
        onDismiss: () {
          _dismissTimer?.cancel();
          _dismissTimer = null;
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(toastDuration, () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _hideAndDismiss() async {
    if (_controller.isAnimating || _controller.status == AnimationStatus.dismissed) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  Color get _bgColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFFF0FDF4); // Emerald 50
      case ToastType.error:
        return const Color(0xFFFFF1F2); // Rose 50
      case ToastType.warning:
        return const Color(0xFFFFFBEB); // Amber 50
      case ToastType.info:
        return const Color(0xFFF0F9FF); // Sky 50
    }
  }

  Color get _borderColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF86EFAC); // Emerald 300
      case ToastType.error:
        return const Color(0xFFFECDD3); // Rose 200
      case ToastType.warning:
        return const Color(0xFFFDE68A); // Amber 200
      case ToastType.info:
        return const Color(0xFFBAE6FD); // Sky 200
    }
  }

  Color get _iconColor {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.primary;
    }
  }

  Color get _textColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF14532D); // Emerald 900
      case ToastType.error:
        return const Color(0xFF881337); // Rose 900
      case ToastType.warning:
        return const Color(0xFF78350F); // Amber 900
      case ToastType.info:
        return const Color(0xFF0C4A6E); // Sky 900
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return LucideIcons.circleCheck;
      case ToastType.error:
        return LucideIcons.circleAlert;
      case ToastType.warning:
        return LucideIcons.triangleAlert;
      case ToastType.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Dismissible(
                  key: const Key('toast_dismissible'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDismiss(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: _iconColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon, size: 18, color: _iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _hideAndDismiss,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              LucideIcons.x,
                              size: 16,
                              color: _textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
