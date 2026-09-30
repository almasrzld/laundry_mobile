import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/payment_model.dart';
import '../../../../data/repositories/payment_repository.dart';

class XenditQrisSheet extends StatefulWidget {
  final XenditQrisPaymentModel payment;
  final IPaymentRepository? paymentRepository;
  final VoidCallback? onPaymentSuccess;

  const XenditQrisSheet({
    super.key,
    required this.payment,
    this.paymentRepository,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required XenditQrisPaymentModel payment,
    IPaymentRepository? paymentRepository,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => XenditQrisSheet(
        payment: payment,
        paymentRepository: paymentRepository,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<XenditQrisSheet> createState() => _XenditQrisSheetState();
}

class _XenditQrisSheetState extends State<XenditQrisSheet> {
  late final IPaymentRepository _paymentRepository;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  late int _secondsRemaining;
  bool _isSimulating = false;
  bool _isPaid = false;

  bool get isVa => widget.payment.isVa;
  bool get isEwallet => widget.payment.isEwallet;
  bool get isQris => widget.payment.isQris;

  @override
  void initState() {
    super.initState();
    _paymentRepository = widget.paymentRepository ?? PaymentRepository();

    // Hitung sisa waktu
    if (widget.payment.expiresAt != null) {
      final diff = widget.payment.expiresAt!.difference(DateTime.now()).inSeconds;
      _secondsRemaining = diff > 0 ? diff : 15 * 60;
    } else {
      _secondsRemaining = 15 * 60;
    }

    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startPolling() {
    // Polling status pembayaran setiap 3 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isPaid) return;
      try {
        final status = await _paymentRepository.getPaymentStatus(widget.payment.orderId);
        if (status == 'PAID' && mounted) {
          timer.cancel();
          _handleSuccess();
        }
      } catch (_) {}
    });
  }

  void _handleSuccess() {
    if (_isPaid) return;
    setState(() => _isPaid = true);
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onPaymentSuccess?.call();
      }
    });
  }

  Future<void> _handleSimulatePay() async {
    if (_isSimulating || _isPaid) return;
    setState(() => _isSimulating = true);

    try {
      final success = await _paymentRepository.simulatePayment(widget.payment.orderId);
      if (success && mounted) {
        _handleSuccess();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Gagal simulasi pembayaran: $e');
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isVa ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFE11938).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isVa ? LucideIcons.landmark : (isEwallet ? LucideIcons.wallet : LucideIcons.qrCode),
                        color: isVa ? AppColors.primary : const Color(0xFFE11938),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVa
                              ? 'Virtual Account ${widget.payment.bankCode ?? ''}'
                              : (isEwallet ? 'E-Wallet ${widget.payment.paymentMethod}' : 'Pembayaran QRIS'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Text(
                          'Verifikasi Otomatis Xendit Gateway',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const Divider(height: 24),

            if (_isPaid) ...[
              // Tampilan Pembayaran Berhasil
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Column(
                  children: [
                    Icon(LucideIcons.circleCheck, color: AppColors.success, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Pembayaran Berhasil Terverifikasi!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pesanan laundry Anda kini siap diproses oleh tim kami.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Countdown Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _secondsRemaining < 180 ? AppColors.error.withValues(alpha: 0.1) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.timer,
                      size: 15,
                      color: _secondsRemaining < 180 ? AppColors.error : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Selesaikan pembayaran dalam ${_formatTime(_secondsRemaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _secondsRemaining < 180 ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Total Tagihan
              Text(
                CurrencyFormatter.formatRupiah(widget.payment.amount),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'No. Invoice: ${widget.payment.invoiceNo}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Tampilan Berdasarkan Tipe Pembayaran (VA vs QRIS / E-Wallet)
              if (isVa) ...[
                // Virtual Account Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VA ${widget.payment.bankCode ?? 'BANK'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            widget.payment.accountName ?? 'ALMAS LAUNDRY',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nomor Virtual Account',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            widget.payment.accountNumber ?? widget.payment.qrString,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              final numToCopy = widget.payment.accountNumber ?? widget.payment.qrString;
                              Clipboard.setData(ClipboardData(text: numToCopy));
                              AppToast.showSuccess(context, 'Nomor VA $numToCopy berhasil disalin!');
                            },
                            icon: const Icon(LucideIcons.copy, size: 13, color: Colors.white),
                            label: const Text('Salin VA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Transfer via ATM, Mobile Banking, atau Internet Banking ke nomor Virtual Account di atas.',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // QR Code Card (QRIS & E-Wallet)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11938).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEwallet ? 'QRIS / EWALLET ${widget.payment.paymentMethod}' : 'QRIS DINAMIS',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11938),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // QR Image
                      if (widget.payment.qrString.isNotEmpty)
                        QrImageView(
                          data: widget.payment.qrString,
                          version: QrVersions.auto,
                          size: 190.0,
                          backgroundColor: Colors.white,
                        ),
                      const SizedBox(height: 8),

                      const Text(
                        'ALMAS LAUNDRY INDONESIA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Ref: ${widget.payment.referenceId}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Salin String QRIS
                if (widget.payment.qrString.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.payment.qrString));
                      AppToast.showSuccess(context, 'String payload pembayaran berhasil disalin!');
                    },
                    icon: const Icon(LucideIcons.copy, size: 14, color: AppColors.primary),
                    label: const Text(
                      'Salin String / Payload QRIS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              // Verification Action Button Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 15, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Konfirmasi Pembayaran',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Setelah menyelesaikan pembayaran pada aplikasi bank / e-wallet, klik tombol di bawah untuk verifikasi status pesanan.',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSimulating ? null : _handleSimulatePay,
                        icon: _isSimulating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(LucideIcons.checkCheck, size: 16, color: Colors.white),
                        label: Text(
                          _isSimulating ? 'Memverifikasi Pembayaran...' : 'Saya Sudah Bayar / Cek Status',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
