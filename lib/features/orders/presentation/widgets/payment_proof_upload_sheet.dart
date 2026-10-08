import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/payment_model.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../data/repositories/service_repository.dart';

class PaymentProofUploadSheet extends StatefulWidget {
  final String orderId;
  final String invoiceNo;
  final int totalAmount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final IPaymentRepository? paymentRepository;
  final VoidCallback? onUploadedSuccess;

  const PaymentProofUploadSheet({
    super.key,
    required this.orderId,
    required this.invoiceNo,
    required this.totalAmount,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.paymentRepository,
    this.onUploadedSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String invoiceNo,
    required int totalAmount,
    String bankName = '',
    String accountNumber = '',
    String accountName = '',
    IPaymentRepository? paymentRepository,
    VoidCallback? onUploadedSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PaymentProofUploadSheet(
        orderId: orderId,
        invoiceNo: invoiceNo,
        totalAmount: totalAmount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
        paymentRepository: paymentRepository,
        onUploadedSuccess: onUploadedSuccess,
      ),
    );
  }

  @override
  State<PaymentProofUploadSheet> createState() => _PaymentProofUploadSheetState();
}

class _PaymentProofUploadSheetState extends State<PaymentProofUploadSheet> {
  late final IPaymentRepository _paymentRepository;
  final ServiceRepository _serviceRepository = ServiceRepository();
  final ImagePicker _picker = ImagePicker();

  List<PaymentMethodModel> _bankOptions = [];
  PaymentMethodModel? _selectedBank;
  bool _isLoadingBanks = true;

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  PaymentProofResultModel? _uploadResult;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _paymentRepository = widget.paymentRepository ?? PaymentRepository();
    _loadBankAccounts();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final allMethods = await _serviceRepository.getPaymentMethods();
      if (mounted) {
        final banks = allMethods.where((m) {
          if (!m.isActive) return false;
          final type = (m.type ?? '').toLowerCase();
          final name = m.name.toLowerCase();
          final code = m.code.toLowerCase();
          final hasAcc = (m.accountNumber ?? '').trim().isNotEmpty;
          return (type.contains('bank') ||
                  type.contains('transfer') ||
                  name.contains('transfer') ||
                  name.contains('bank') ||
                  code.contains('transfer') ||
                  code.contains('bank') ||
                  hasAcc) &&
              !code.contains('qris') &&
              !code.contains('laundrypay') &&
              !code.contains('tunai') &&
              !code.contains('cash');
        }).toList();

        PaymentMethodModel? initial;
        if (widget.bankName.isNotEmpty) {
          try {
            initial = banks.firstWhere(
              (b) =>
                  b.name.toLowerCase() == widget.bankName.toLowerCase() ||
                  b.code.toLowerCase() == widget.bankName.toLowerCase(),
            );
          } catch (_) {
            if (widget.accountNumber.isNotEmpty) {
              initial = PaymentMethodModel(
                id: '0',
                name: widget.bankName,
                code: 'manual_transfer',
                accountNumber: widget.accountNumber,
                accountName: widget.accountName,
              );
              banks.insert(0, initial);
            }
          }
        }

        if (initial == null && banks.isNotEmpty) {
          initial = banks.first;
        }

        setState(() {
          _bankOptions = banks;
          _selectedBank = initial;
          _isLoadingBanks = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBanks = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _inlineError = null);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (picked == null) return;

      final extension = picked.name.split('.').last.toLowerCase();
      final allowedExtensions = ['jpg', 'jpeg', 'png'];

      // Validasi format file: Hanya JPG, JPEG, dan PNG
      if (!allowedExtensions.contains(extension)) {
        const errorMsg = 'Format file tidak didukung! Hanya format JPG, JPEG, atau PNG yang diizinkan.';
        if (mounted) {
          setState(() => _inlineError = errorMsg);
          AppToast.showError(context, errorMsg);
        }
        return;
      }

      final bytes = await picked.readAsBytes();

      setState(() {
        _selectedImage = picked;
        _imageBytes = bytes;
        _inlineError = null;
      });
    } catch (e) {
      final errorMsg = 'Gagal memilih gambar: $e';
      if (mounted) {
        setState(() => _inlineError = errorMsg);
        AppToast.showError(context, errorMsg);
      }
    }
  }

  Future<void> _uploadProof() async {
    if (_imageBytes == null || _selectedImage == null) return;

    setState(() {
      _isUploading = true;
      _inlineError = null;
    });

    try {
      final result = await _paymentRepository.uploadPaymentProof(
        widget.orderId,
        _imageBytes!,
        _selectedImage!.name,
      );

      setState(() {
        _uploadResult = result;
        _inlineError = null;
      });

      if (mounted) {
        final successMsg = result.message.isNotEmpty
            ? result.message
            : 'Bukti pembayaran berhasil diunggah (WebP) dan sedang menunggu verifikasi admin.';
        AppToast.showSuccess(context, successMsg);
        widget.onUploadedSuccess?.call();
      }
    } catch (e) {
      final errorMsg = 'Gagal mengunggah bukti pembayaran: $e';
      if (mounted) {
        setState(() => _inlineError = errorMsg);
        AppToast.showError(context, errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.receipt, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upload Bukti Transfer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Pesanan #${widget.invoiceNo}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
            const Divider(height: 20),

            // Dropdown Pilihan Bank Transfer
            if (_isLoadingBanks) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (_bankOptions.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Bank Tujuan Transfer:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PaymentMethodModel>(
                    initialValue: _selectedBank != null && _bankOptions.contains(_selectedBank)
                        ? _selectedBank
                        : _bankOptions.first,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(LucideIcons.landmark, size: 18, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    items: _bankOptions.map((bank) {
                      return DropdownMenuItem<PaymentMethodModel>(
                        value: bank,
                        child: Text(
                          bank.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBank = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],

            // Rekening Tujuan Card
            Builder(
              builder: (context) {
                final activeBank = _selectedBank;
                final effectiveBankName = activeBank?.name ?? (widget.bankName.isNotEmpty ? widget.bankName : 'Transfer Bank');
                final effectiveAccountNumber = activeBank?.accountNumber?.isNotEmpty == true
                    ? activeBank!.accountNumber!
                    : widget.accountNumber;
                final effectiveAccountName = activeBank?.accountName?.isNotEmpty == true
                    ? activeBank!.accountName!
                    : widget.accountName;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.creditCard, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                effectiveBankName.isNotEmpty
                                    ? 'Rekening $effectiveBankName'
                                    : 'Total Tagihan Transfer',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.formatRupiah(widget.totalAmount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      if (effectiveAccountNumber.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    effectiveAccountNumber,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (effectiveAccountName.isNotEmpty)
                                    Text(
                                      'a/n $effectiveAccountName',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: effectiveAccountNumber));
                                  AppToast.showSuccess(context, 'Nomor rekening $effectiveAccountNumber berhasil disalin!');
                                },
                                icon: const Icon(LucideIcons.copy, size: 12, color: Colors.white),
                                label: const Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Silakan transfer tepat sejumlah ${CurrencyFormatter.formatRupiah(widget.totalAmount)} ke nomor rekening $effectiveBankName di atas, lalu lampirkan foto bukti transfer di bawah.',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ] else if (!_isLoadingBanks) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Informasi nomor rekening belum tersedia. Silakan hubungi customer care kami.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Inline Error Banner if present
            if (_inlineError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.circleAlert, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF881337), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_uploadResult != null) ...[
              // Tampilan Berhasil Diunggah
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.circleCheck, color: AppColors.success, size: 42),
                    const SizedBox(height: 10),
                    const Text(
                      'Bukti Transfer Berhasil Diunggah!',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tim admin/kasir akan segera memverifikasi pembayaran Anda.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Upload Area
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_imageBytes!, fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.camera, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text('Ganti Foto', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.imagePlus, size: 36, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text(
                              'Ketuk untuk Pilih Foto Bukti Transfer',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Format: JPG, JPEG, PNG',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Pilih dari Kamera vs Galeri
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(LucideIcons.camera, size: 14),
                      label: const Text('Buka Kamera', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(LucideIcons.image, size: 14),
                      label: const Text('Pilih dari Galeri', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tombol Submit Upload
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_imageBytes == null || _isUploading) ? null : _uploadProof,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.uploadCloud, size: 16, color: Colors.white),
                  label: Text(
                    _isUploading ? 'Mengunggah & Mengonversi ke WebP...' : 'Kirim Bukti Pembayaran',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
