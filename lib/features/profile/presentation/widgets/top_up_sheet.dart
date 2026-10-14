import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../data/repositories/service_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../services/presentation/widgets/xendit_qris_sheet.dart';

class TopUpSheet extends StatefulWidget {
  final UserModel user;
  final int? prefillAmount;
  final String? prefillReason;
  final VoidCallback? onTopUpSuccess;

  const TopUpSheet({
    super.key,
    required this.user,
    this.prefillAmount,
    this.prefillReason,
    this.onTopUpSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel user,
    int? prefillAmount,
    String? prefillReason,
    VoidCallback? onTopUpSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TopUpSheet(
        user: user,
        prefillAmount: prefillAmount,
        prefillReason: prefillReason,
        onTopUpSuccess: onTopUpSuccess,
      ),
    );
  }

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  late final TextEditingController _amountCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final UserRepository _userRepository = UserRepository();
  final ServiceRepository _serviceRepository = ServiceRepository();

  PaymentMethodModel? _selectedPayment;
  bool _isSubmitting = false;
  Uint8List? _proofBytes;
  String? _proofFilename;

  @override
  void initState() {
    super.initState();
    final defaultAmt = widget.prefillAmount != null && widget.prefillAmount! > 0
        ? max(10000, widget.prefillAmount!)
        : 50000;
    _amountCtrl = TextEditingController(text: defaultAmt.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _setQuickAmount(int val) {
    setState(() {
      _amountCtrl.text = val.toString();
    });
  }

  Future<void> _pickProof(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;

      final extension = picked.name.split('.').last.toLowerCase();
      final allowedExtensions = ['jpg', 'jpeg', 'png'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          AppToast.showError(
            context,
            'Format file tidak didukung! Hanya format JPG, JPEG, atau PNG yang diizinkan.',
          );
        }
        return;
      }

      final bytes = await picked.readAsBytes();
      setState(() {
        _proofBytes = bytes;
        _proofFilename = picked.name;
      });
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Gagal memilih gambar: $e');
      }
    }
  }

  Future<void> _submitTopup(PaymentMethodModel currentMethod) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 10000) {
      AppToast.showError(context, 'Minimal nominal top-up adalah Rp 10.000');
      return;
    }

    final isQris = currentMethod.code.toLowerCase().contains('qris') ||
        currentMethod.name.toLowerCase().contains('qris');

    setState(() => _isSubmitting = true);

    try {
      if (isQris) {
        final qrisPayment = await _paymentRepository.createXenditTopupQris(amount);
        if (!mounted) return;
        Navigator.pop(context);

        XenditQrisSheet.show(
          context,
          payment: qrisPayment,
          paymentRepository: _paymentRepository,
          onPaymentSuccess: () {
            widget.onTopUpSuccess?.call();
            final rootCtx = Navigator.of(context, rootNavigator: true).context;
            AppToast.showSuccess(
              rootCtx,
              'Top-up saldo ${CurrencyFormatter.formatRupiah(amount)} via QRIS berhasil diverifikasi otomatis!',
            );
          },
        );
      } else {
        await _userRepository.topupWallet(
          amount: amount,
          paymentMethod: currentMethod.name,
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          proofBytes: _proofBytes,
          proofFilename: _proofFilename,
        );

        if (!mounted) return;
        Navigator.pop(context);

        widget.onTopUpSuccess?.call();

        AppToast.showSuccess(
          context,
          'Pengajuan top-up saldo ${CurrencyFormatter.formatRupiah(amount)} via ${currentMethod.name} berhasil dikirim! Menunggu verifikasi admin.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.showError(context, 'Gagal memproses top-up: $e');
      }
    }
  }

  Widget _buildQuickAmountChip(int val, String label, VoidCallback onTap) {
    final currentVal = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final isSelected = currentVal == val;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.wallet, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Isi Saldo LaundryPay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const Divider(height: 20, color: AppColors.border),

              // Prefill shortage info alert if applicable
              if (widget.prefillReason != null && widget.prefillReason!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kekurangan Pembayaran Pesanan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.prefillReason!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Current Balance Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo LaundryPay Saat Ini:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      CurrencyFormatter.formatRupiah(widget.user.laundryPayBalance),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Input Nominal
              const Text(
                'Nominal Pengisian (Rp) *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  hintText: 'Minimal 10.000',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal pengisian wajib diisi';
                  }
                  final n = int.tryParse(val.trim());
                  if (n == null || n < 10000) {
                    return 'Minimal pengisian adalah Rp 10.000';
                  }
                  return null;
                },
              ),

              // Quick Chips
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.prefillAmount != null && widget.prefillAmount! > 0)
                    _buildQuickAmountChip(
                      max(10000, widget.prefillAmount!),
                      'Pas: ${CurrencyFormatter.formatRupiah(max(10000, widget.prefillAmount!))}',
                      () => _setQuickAmount(max(10000, widget.prefillAmount!)),
                    ),
                  _buildQuickAmountChip(20000, 'Rp 20.000', () => _setQuickAmount(20000)),
                  _buildQuickAmountChip(50000, 'Rp 50.000', () => _setQuickAmount(50000)),
                  _buildQuickAmountChip(100000, 'Rp 100.000', () => _setQuickAmount(100000)),
                  _buildQuickAmountChip(200000, 'Rp 200.000', () => _setQuickAmount(200000)),
                ],
              ),

              const SizedBox(height: 14),

              // Metode Pembayaran Dropdown Standar
              const Text(
                'Metode Pembayaran *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<PaymentMethodModel>>(
                future: _serviceRepository.getPaymentMethods(),
                builder: (ctx, snap) {
                  final rawMethods = snap.data ?? [];
                  final filtered = rawMethods.where((m) {
                    final code = m.code.toLowerCase();
                    final name = m.name.toLowerCase();
                    final type = (m.type ?? '').toLowerCase();
                    final isCash = type == 'cash' || code.contains('cash') || name.contains('tunai') || code.contains('pos');
                    final isLPay = type == 'laundrypay' || code.contains('laundrypay') || name.contains('laundrypay');
                    return m.isActive && !isCash && !isLPay;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Belum ada metode pembayaran top-up yang aktif.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    );
                  }

                  // Deduplicate by code
                  final seenCodes = <String>{};
                  final options = <PaymentMethodModel>[];
                  for (final m in filtered) {
                    final codeKey = m.code.trim().toUpperCase();
                    if (codeKey.isNotEmpty && seenCodes.add(codeKey)) {
                      options.add(m);
                    }
                  }

                  final activeMethod = options.firstWhere(
                    (o) => _selectedPayment != null && o.code.toUpperCase() == _selectedPayment!.code.toUpperCase(),
                    orElse: () => options.first,
                  );

                  if (_selectedPayment == null || _selectedPayment!.code.toUpperCase() != activeMethod.code.toUpperCase()) {
                    _selectedPayment = activeMethod;
                  }

                  final isQrisSelected = activeMethod.code.toLowerCase().contains('qris') ||
                      activeMethod.name.toLowerCase().contains('qris');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: activeMethod.code,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        items: options.map((m) {
                          final isQ = m.code.toLowerCase().contains('qris') || m.name.toLowerCase().contains('qris');
                          return DropdownMenuItem<String>(
                            value: m.code,
                            child: Row(
                              children: [
                                Icon(
                                  isQ ? LucideIcons.qrCode : LucideIcons.building,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPayment = options.firstWhere((e) => e.code == val);
                            });
                          }
                        },
                      ),

                      // Account Details Card
                      if (!isQrisSelected && activeMethod.accountNumber != null && activeMethod.accountNumber!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rekening ${activeMethod.name}:',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: activeMethod.accountNumber!));
                                      AppToast.showSuccess(context, 'Nomor rekening ${activeMethod.accountNumber} berhasil disalin!');
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(LucideIcons.copy, size: 12, color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeMethod.accountNumber!,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                              ),
                              if (activeMethod.accountName != null && activeMethod.accountName!.isNotEmpty)
                                Text(
                                  'a/n ${activeMethod.accountName}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Upload Bukti Transfer Manual
                        const Text(
                          'Bukti Pembayaran / Struk Transfer (Opsional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        if (_proofBytes != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.checkCircle2, color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _proofFilename ?? 'Foto bukti transfer berhasil dipilih',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() {
                                    _proofBytes = null;
                                    _proofFilename = null;
                                  }),
                                  icon: const Icon(LucideIcons.x, size: 16, color: Colors.red),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickProof(ImageSource.gallery),
                                  icon: const Icon(LucideIcons.image, size: 14),
                                  label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickProof(ImageSource.camera),
                                  icon: const Icon(LucideIcons.camera, size: 14),
                                  label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],

                      if (isQrisSelected) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.sparkles, color: Color(0xFF059669), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'QRIS Otomatis: Kode QR akan langsung dibuat dan diverifikasi secara instan.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Catatan Pengirim
                      const Text(
                        'Catatan / Berita Transfer (Opsional)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Isi saldo LaundryPay via BCA',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : () => _submitTopup(_selectedPayment!),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(isQrisSelected ? LucideIcons.qrCode : LucideIcons.send, size: 16),
                          label: Text(
                            _isSubmitting
                                ? 'Memproses Pengajuan...'
                                : (isQrisSelected ? 'Lanjut Bayar via QRIS' : 'Kirim Pengajuan Top-Up'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
