import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/launcher_helper.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/payment_model.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../widgets/payment_proof_upload_sheet.dart';
import 'package:laundry_app/features/services/presentation/widgets/xendit_qris_sheet.dart';

class OrderDetailPage extends StatefulWidget {
  final OrderModel? order;
  final String? orderId;
  final IOrderRepository? orderRepository;

  const OrderDetailPage({
    super.key,
    this.order,
    this.orderId,
    this.orderRepository,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final IOrderRepository _orderRepository;
  late final IPaymentRepository _paymentRepository;
  OrderModel? _currentOrder;
  UserModel? _currentUser;
  XenditPaymentResultModel? _paymentDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _paymentRepository = PaymentRepository();
    _currentOrder = widget.order;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    final effectiveId = widget.order?.id ?? widget.orderId;
    final user = await SessionService.getUser();
    if (effectiveId == null) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _currentUser = user;
      _isLoading = _currentOrder == null;
    });
    final fresh = await _orderRepository.getOrderById(effectiveId);
    final paymentInfo = await _paymentRepository.getPaymentDetails(effectiveId);
    if (mounted) {
      setState(() {
        if (fresh != null) {
          _currentOrder = fresh;
        }
        _paymentDetails = paymentInfo;
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentOrder == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_currentOrder == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }

    final order = _currentOrder!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _refreshDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header Card (Solid Flat)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.invoiceNo,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            StatusBadge(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          order.serviceName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dipesan: ${CurrencyFormatter.formatDate(order.orderDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Tracking Timeline
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.droplets, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Status Pelacakan SOP Cucian',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (order.timeline.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Belum ada riwayat status pengerjaan.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: order.timeline.length,
                            itemBuilder: (context, index) {
                              final step = order.timeline[index];
                              final isLast = index == order.timeline.length - 1;

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Timeline indicator
                                    Column(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: step.isCompleted
                                                ? AppColors.primary
                                                : step.isCurrent
                                                    ? AppColors.primary
                                                    : AppColors.surfaceVariant,
                                            border: Border.all(
                                              color: step.isCompleted
                                                  ? AppColors.primary
                                                  : step.isCurrent
                                                      ? AppColors.primary
                                                      : AppColors.border,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            step.isCompleted
                                                ? LucideIcons.check
                                                : step.isCurrent
                                                    ? LucideIcons.refreshCw
                                                    : LucideIcons.circle,
                                            size: 11,
                                            color: (step.isCompleted || step.isCurrent)
                                                ? Colors.white
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              color: step.isCompleted
                                                  ? AppColors.primary
                                                  : AppColors.border,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),
                                    // Content
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  step.title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: step.isCurrent
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    color: step.isCurrent
                                                        ? AppColors.primary
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  step.time,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              step.description,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rating & Tips Prompt (When order completed)
                  if (order.isCompleted) ...[
                    _buildRatingCard(order),
                    const SizedBox(height: 16),
                  ],

                  // Courier Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(LucideIcons.user, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kurir Bertugas',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                order.courierName.trim().isNotEmpty
                                    ? order.courierName.trim()
                                    : 'Menunggu penugasan kurir',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (order.courierPhone.trim().isNotEmpty)
                          IconButton.filled(
                            onPressed: () => _showCourierContactSheet(order),
                            icon: const Icon(LucideIcons.phone, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Address & Order Notes Card
                  Container(
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
                          'Informasi Pengiriman & Catatan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Alamat Penjemputan / Pengantaran',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.pickupAddress.isNotEmpty ? order.pickupAddress : 'Alamat sesuai profil pelanggan',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (order.notes.trim().isNotEmpty) ...[
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.clipboardList, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Catatan & Metode Pembayaran',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order.notes.trim(),
                                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price Details Card
                  Container(
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
                          'Rincian Pembayaran',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPriceRow(
                          'Biaya Layanan (${order.quantity} ${order.unit})',
                          CurrencyFormatter.formatRupiah(order.subtotal),
                        ),
                        const SizedBox(height: 8),
                        _buildPriceRow(
                          'Biaya Ongkir Antar-Jemput',
                          CurrencyFormatter.formatRupiah(order.deliveryFee),
                        ),
                        if (order.discount > 0) ...[
                          const SizedBox(height: 8),
                          _buildPriceRow(
                            'Diskon Promo',
                            '- ${CurrencyFormatter.formatRupiah(order.discount)}',
                            isDiscount: true,
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Tagihan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatRupiah(order.totalAmount),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status Verifikasi & Upload Bukti Pembayaran
                        Builder(
                          builder: (context) {
                            final isPaid = order.notes.toUpperCase().contains('LUNAS') ||
                                _paymentDetails?.status == 'PAID';
                            final hasProof = _paymentDetails?.proofImage != null &&
                                _paymentDetails!.proofImage!.isNotEmpty;
                            final isCash = order.notes.toLowerCase().contains('tunai') ||
                                order.notes.toLowerCase().contains('cash') ||
                                order.notes.toLowerCase().contains('cod');
                            final isQris = order.notes.toLowerCase().contains('qris') ||
                                (_paymentDetails?.paymentMethod.toLowerCase().contains('qris') ?? false);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : hasProof
                                        ? AppColors.warning.withValues(alpha: 0.08)
                                        : AppColors.primaryLight.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPaid
                                      ? AppColors.success.withValues(alpha: 0.3)
                                      : hasProof
                                          ? AppColors.warning.withValues(alpha: 0.4)
                                          : AppColors.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isPaid
                                                ? LucideIcons.circleCheck
                                                : (hasProof ? LucideIcons.clock : LucideIcons.receipt),
                                            size: 15,
                                            color: isPaid
                                                ? AppColors.success
                                                : (hasProof ? AppColors.warning : AppColors.primary),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isPaid
                                                ? 'Pembayaran Lunas'
                                                : (hasProof ? 'Menunggu Verifikasi Admin' : 'Status: Menunggu Pembayaran'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isPaid
                                                  ? AppColors.success
                                                  : (hasProof ? AppColors.warning : AppColors.primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isPaid && !isCash)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isQris) ...[
                                              ElevatedButton.icon(
                                                onPressed: () => _openQrisSheet(order),
                                                icon: const Icon(LucideIcons.qrCode, size: 12, color: Colors.white),
                                                label: const Text(
                                                  'Bayar QRIS',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: 0,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                PaymentProofUploadSheet.show(
                                                  context,
                                                  orderId: order.id,
                                                  invoiceNo: order.invoiceNo,
                                                  totalAmount: order.totalAmount,
                                                  onUploadedSuccess: () => _refreshDetail(),
                                                );
                                              },
                                              icon: const Icon(LucideIcons.uploadCloud, size: 12, color: Colors.white),
                                              label: Text(
                                                hasProof ? 'Ganti Bukti' : 'Upload Bukti',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isQris ? AppColors.surfaceVariant : AppColors.primary,
                                                foregroundColor: isQris ? AppColors.textPrimary : Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (hasProof && !isPaid) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Bukti transfer (WebP \u2264 1MB) berhasil diunggah dan sedang diperiksa oleh kasir/admin.',
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Bantuan Customer Care',
                    icon: LucideIcons.messageSquare,
                    isOutlined: true,
                    onPressed: () => _showCustomerCareSheet(order),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDiscount ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _openQrisSheet(OrderModel order) async {
    try {
      AppToast.showInfo(context, 'Memuat QRIS...');
      final payment = await _paymentRepository.createXenditPayment(order.id, paymentMethod: 'QRIS');
      if (!mounted) return;
      XenditQrisSheet.show(
        context,
        payment: payment,
        paymentRepository: _paymentRepository,
        onPaymentSuccess: () {
          _refreshDetail();
          AppToast.showSuccess(context, 'Pembayaran berhasil diverifikasi otomatis!');
        },
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Gagal memuat QRIS: $e');
      }
    }
  }

  void _showCourierContactSheet(OrderModel order) {
    final courierName = order.courierName.trim().isNotEmpty ? order.courierName.trim() : 'Kurir Almas';
    final courierPhone = order.courierPhone.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(LucideIcons.user, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                courierName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.badgeCheck, color: Color(0xFF0284C7), size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          courierPhone,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action 1: WhatsApp
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.green.shade200)),
                tileColor: const Color(0xFFF0FDF4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 18),
                ),
                title: const Text(
                  'Chat via WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                ),
                subtitle: const Text(
                  'Konfirmasi penjemputan/pengantaran cucian',
                  style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF15803D)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final msg = 'Halo $courierName, saya pelanggan Almas Laundry untuk pesanan #${order.invoiceNo}. Mau konfirmasi terkait penjemputan/pengantaran cucian saya.';
                  final ok = await LauncherHelper.openWhatsApp(phone: courierPhone, message: msg);
                  if (!ok && mounted) {
                    LauncherHelper.copyToClipboard(courierPhone);
                    AppToast.showInfo(context, 'Nomor kurir ($courierPhone) berhasil disalin ke clipboard.');
                  }
                },
              ),
              const SizedBox(height: 10),

              // Action 2: Phone Call
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFBAE6FD))),
                tileColor: const Color(0xFFF0F9FF),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.phone, color: Colors.white, size: 18),
                ),
                title: const Text(
                  'Panggilan Telepon',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0369A1)),
                ),
                subtitle: const Text(
                  'Panggil nomor seluler kurir secara langsung',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF0284C7)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await LauncherHelper.openPhoneCall(courierPhone);
                  if (!ok && mounted) {
                    LauncherHelper.copyToClipboard(courierPhone);
                    AppToast.showInfo(context, 'Nomor kurir ($courierPhone) telah disalin ke clipboard.');
                  }
                },
              ),
              const SizedBox(height: 10),

              // Action 3: Copy Phone
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                tileColor: AppColors.surfaceVariant,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.copy, color: Colors.white, size: 18),
                ),
                title: const Text(
                  'Salin Nomor Telepon',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  courierPhone,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(LucideIcons.clipboardCheck, size: 18, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  LauncherHelper.copyToClipboard(courierPhone);
                  AppToast.showSuccess(context, 'Nomor kurir $courierPhone berhasil disalin!');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerCareSheet(OrderModel order) {
    const csPhone = '+6281215199230';
    const csDisplayPhone = '+62 812-1519-9230';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.headset, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bantuan Customer Care',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Terkait Pesanan #${order.invoiceNo}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Card CS WhatsApp Utama
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('WhatsApp CS Almas Laundry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                Text('Online & Respon Cepat • 07.00 - 21.00 WIB', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        csDisplayPhone,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(sheetCtx);
                                final msg = 'Halo Customer Care Almas Laundry, saya ingin menanyakan bantuan terkait pesanan saya #${order.invoiceNo} (${order.serviceName}). Mohon bantuannya.';
                                final ok = await LauncherHelper.openWhatsApp(phone: csPhone, message: msg);
                                if (!ok && mounted) {
                                  LauncherHelper.copyToClipboard(csPhone);
                                  AppToast.showInfo(context, 'Nomor CS disalin. Silakan buka aplikasi WhatsApp.');
                                }
                              },
                              icon: const Icon(LucideIcons.messageSquare, size: 16),
                              label: const Text('Chat WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () {
                              LauncherHelper.copyToClipboard(csPhone);
                              AppToast.showSuccess(context, 'Nomor WhatsApp CS berhasil disalin!');
                            },
                            icon: const Icon(LucideIcons.copy, size: 18, color: Color(0xFF166534)),
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card Hotline Telepon
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                  tileColor: AppColors.surface,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.phoneCall, color: AppColors.primary, size: 18),
                  ),
                  title: const Text('Telepon Hotline CS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Bicara langsung dengan staf layanan pelanggan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final ok = await LauncherHelper.openPhoneCall(csPhone);
                    if (!ok && mounted) {
                      LauncherHelper.copyToClipboard(csPhone);
                      AppToast.showInfo(context, 'Nomor hotline CS disalin ke clipboard.');
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Pertanyaan Cepat Terkait Pesanan
                const Text(
                  'Topik Pertanyaan Cepat:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                _buildQuickQuestionChip(
                  context,
                  sheetCtx,
                  order,
                  'Kapan cucian saya selesai & diantar?',
                  'Halo CS Almas Laundry, saya ingin menanyakan estimasi cucian selesai dan jadwal pengantaran untuk pesanan #${order.invoiceNo}.',
                ),
                _buildQuickQuestionChip(
                  context,
                  sheetCtx,
                  order,
                  'Ingin ubah alamat / waktu pengantaran',
                  'Halo CS Almas Laundry, saya ingin mengajukan penyesuaian alamat atau waktu antar pesanan #${order.invoiceNo}.',
                ),
                _buildQuickQuestionChip(
                  context,
                  sheetCtx,
                  order,
                  'Konfirmasi pembayaran & rincian nota',
                  'Halo CS Almas Laundry, saya ingin konfirmasi pembayaran dan rincian tagihan pesanan #${order.invoiceNo}.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickQuestionChip(
    BuildContext context,
    BuildContext sheetCtx,
    OrderModel order,
    String label,
    String templateMessage,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          Navigator.pop(sheetCtx);
          const csPhone = '+6281215199230';
          await LauncherHelper.openWhatsApp(phone: csPhone, message: templateMessage);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.messageSquare, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(LucideIcons.send, size: 13, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  bool _checkIsCustomerOwner(OrderModel order) {
    if (_currentUser == null) return false;

    // Jika ID pesanan atau nama pelanggan cocok dengan user yang sedang login, maka dia adalah pemilik pesanan
    if (order.userId != null && order.userId!.isNotEmpty) {
      return order.userId == _currentUser!.id;
    }
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      return order.customerName!.trim().toLowerCase() == _currentUser!.displayName.trim().toLowerCase();
    }

    return !_currentUser!.isCourier;
  }

  Widget _buildRatingCard(OrderModel order) {
    final isCustomerOwner = _checkIsCustomerOwner(order);

    if (order.isRated) {
      final isCourier = _currentUser?.isCourier == true;
      final cardTitle = isCustomerOwner ? 'Ulasan & Penilaian Anda' : 'Ulasan & Penilaian Pelanggan';
      final cardSubtitle = isCustomerOwner
          ? 'Terima kasih atas masukan berharga Anda!'
          : (order.customerName != null && order.customerName!.trim().isNotEmpty
              ? 'Dari ${order.customerName}'
              : 'Penilaian dari pelanggan');

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.star, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                      Text(
                        cardSubtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.star, color: Colors.amber, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${order.rating}.0',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Star display
            Row(
              children: List.generate(5, (index) {
                final starNum = index + 1;
                final isFilled = order.rating != null && starNum <= order.rating!;
                return Icon(
                  LucideIcons.star,
                  color: isFilled ? Colors.amber : Colors.grey.shade300,
                  size: 20,
                );
              }),
            ),
            if (order.review != null && order.review!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Text(
                  '"${order.review!.trim()}"',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF166534)),
                ),
              ),
            ],
            if (order.tipAmount != null && order.tipAmount! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(LucideIcons.heartHandshake, color: Color(0xFF059669), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isCourier
                        ? 'Tips Diterima: ${CurrencyFormatter.formatRupiah(order.tipAmount!)}'
                        : 'Tips Kurir: ${CurrencyFormatter.formatRupiah(order.tipAmount!)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                ],
              ),
            ],
            if (isCustomerOwner) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showAppStoreRatingDialog,
                  icon: const Icon(LucideIcons.star, size: 14, color: Color(0xFFD97706)),
                  label: const Text('Beri Rating di Play Store / App Store', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    backgroundColor: const Color(0xFFFFFBEB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Unrated: Hanya ditampilkan kepada pelanggan pemilik pesanan
    if (!isCustomerOwner) {
      return const SizedBox.shrink();
    }

    // Unrated: Prompt banner untuk Pelanggan Pemilik Pesanan
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.star, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan Telah Selesai!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    Text(
                      'Bagikan kepuasan Anda & beri apresiasi kurir',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Interactive quick star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              return InkWell(
                onTap: () => _showRatingAndTipsSheet(order, initialRating: starNum),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(
                    LucideIcons.star,
                    color: Color(0xFFF59E0B),
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRatingAndTipsSheet(order, initialRating: 5),
              icon: const Icon(LucideIcons.star, size: 16),
              label: const Text('Beri Rating & Tips Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingAndTipsSheet(OrderModel order, {int initialRating = 5}) {
    int selectedRating = initialRating;
    final reviewController = TextEditingController();
    int selectedTip = 0;
    bool isCustomTip = false;
    final customTipController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final (moodText, moodIcon, moodColor) = switch (selectedRating) {
              5 => ('Sangat Puas & Luar Biasa!', LucideIcons.sparkles, const Color(0xFFD97706)),
              4 => ('Puas & Bersih Rapi', LucideIcons.smile, const Color(0xFF059669)),
              3 => ('Cukup Baik', LucideIcons.meh, const Color(0xFF2563EB)),
              2 => ('Kurang Puas', LucideIcons.frown, const Color(0xFFEA580C)),
              _ => ('Sangat Kecewa', LucideIcons.thumbsDown, const Color(0xFFDC2626)),
            };

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.star, color: Color(0xFFF59E0B), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Penilaian & Ulasan Layanan',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Pesanan #${order.invoiceNo} • ${order.serviceName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Star Selector
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              final isSelected = starNum <= selectedRating;
                              return InkWell(
                                onTap: () => setModalState(() => selectedRating = starNum),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Icon(
                                    LucideIcons.star,
                                    color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                                    size: 38,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(moodIcon, size: 15, color: moodColor),
                                const SizedBox(width: 6),
                                Text(
                                  moodText,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: moodColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Review Input
                    const Text(
                      'Ulasan Anda (Opsional):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ceritakan kepuasan Anda mengenai kebersihan cucian, aroma parfum, atau keramahan kurir...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tips Section
                    Row(
                      children: [
                        const Icon(LucideIcons.heartHandshake, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apresiasi Tips untuk ${order.courierName.isNotEmpty ? order.courierName : "Kurir"}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const Text(
                                '100% tips akan langsung diserahkan kepada kurir bertugas',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Tip Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTipChip(0, 'Rp 0', selectedTip == 0 && !isCustomTip, () {
                          setModalState(() {
                            selectedTip = 0;
                            isCustomTip = false;
                          });
                        }),
                        _buildTipChip(2000, '+Rp 2.000', selectedTip == 2000 && !isCustomTip, () {
                          setModalState(() {
                            selectedTip = 2000;
                            isCustomTip = false;
                          });
                        }),
                        _buildTipChip(5000, '+Rp 5.000', selectedTip == 5000 && !isCustomTip, () {
                          setModalState(() {
                            selectedTip = 5000;
                            isCustomTip = false;
                          });
                        }),
                        _buildTipChip(10000, '+Rp 10.000', selectedTip == 10000 && !isCustomTip, () {
                          setModalState(() {
                            selectedTip = 10000;
                            isCustomTip = false;
                          });
                        }),
                        _buildTipChip(20000, '+Rp 20.000', selectedTip == 20000 && !isCustomTip, () {
                          setModalState(() {
                            selectedTip = 20000;
                            isCustomTip = false;
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                final tipFinal = isCustomTip
                                    ? (int.tryParse(customTipController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
                                    : selectedTip;

                                final success = await _orderRepository.submitRating(
                                  order.id,
                                  rating: selectedRating,
                                  review: reviewController.text.trim(),
                                  tipAmount: tipFinal,
                                );

                                if (!sheetCtx.mounted) return;
                                Navigator.pop(sheetCtx);

                                if (!mounted) return;

                                if (success) {
                                  await _refreshDetail();
                                  if (!mounted) return;
                                  AppToast.showSuccess(context, 'Ulasan & tips Anda berhasil disimpan. Terima kasih!');

                                  // Jika rating tinggi (4 atau 5), ajak ulas di Play Store / App Store
                                  if (selectedRating >= 4) {
                                    _showAppStoreRatingDialog();
                                  }
                                } else {
                                  AppToast.showError(context, 'Gagal mengirim ulasan. Silakan coba lagi.');
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Kirim Penilaian & Tips',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTipChip(int value, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF059669) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF065F46) : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showAppStoreRatingDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.star, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'Terima Kasih Banyak! 🌟',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Text(
            'Kepuasan Anda adalah kebanggaan kami! Luangkan 10 detik untuk memberikan rating bintang 5 di Google Play Store atau Apple App Store agar Almas Laundry dapat terus berkembang.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      LauncherHelper.openPlayStore();
                    },
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Beri Rating di Google Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      LauncherHelper.openAppStore();
                    },
                    icon: const Icon(LucideIcons.apple, size: 16),
                    label: const Text('Beri Rating di App Store 🍏', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Nanti Saja', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
