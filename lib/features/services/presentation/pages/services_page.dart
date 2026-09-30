import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/service_model.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../data/repositories/service_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../widgets/service_card.dart';
import '../widgets/xendit_qris_sheet.dart';
import '../../../orders/presentation/widgets/payment_proof_upload_sheet.dart';

class ServicesPage extends StatefulWidget {
  final IServiceRepository? serviceRepository;
  final IOrderRepository? orderRepository;
  final IUserRepository? userRepository;

  const ServicesPage({
    super.key,
    this.serviceRepository,
    this.orderRepository,
    this.userRepository,
  });

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final IServiceRepository _serviceRepository;
  late final IOrderRepository _orderRepository;
  late final IUserRepository _userRepository;

  String _selectedCategoryId = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _services = [];
  List<ServiceCategoryModel> _categories = [];
  List<PerfumeModel> _perfumes = [];
  List<PaymentMethodModel> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _serviceRepository = widget.serviceRepository ?? ServiceRepository();
    _orderRepository = widget.orderRepository ?? OrderRepository();
    _userRepository = widget.userRepository ?? UserRepository();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _serviceRepository.getServices(categoryId: _selectedCategoryId, query: _searchQuery),
        _serviceRepository.getCategories(),
        _serviceRepository.getPerfumes(),
        _serviceRepository.getPaymentMethods(),
      ]);

      if (mounted) {
        setState(() {
          _services = results[0] as List<ServiceModel>;
          _categories = results[1] as List<ServiceCategoryModel>;
          _perfumes = results[2] as List<PerfumeModel>;
          _paymentMethods = results[3] as List<PaymentMethodModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _serviceRepository.getServices(
        categoryId: _selectedCategoryId,
        query: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _services = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategoryChanged(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadServices();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadServices();
  }

  void _showBookingBottomSheet(BuildContext context, ServiceModel service) async {
    double quantity = 1.0;
    final noteController = TextEditingController();
    final addressController = TextEditingController();
    final user = await _userRepository.getProfile();
    final addresses = await _userRepository.getAddresses();
    
    // Pastikan master parfum dan metode pembayaran terambil
    if (_perfumes.isEmpty) {
      final fetchedPerfumes = await _serviceRepository.getPerfumes();
      if (mounted) setState(() => _perfumes = fetchedPerfumes);
    }
    if (_paymentMethods.isEmpty) {
      final fetchedPayments = await _serviceRepository.getPaymentMethods();
      if (mounted) setState(() => _paymentMethods = fetchedPayments);
    }
    
    String selectedAddress = user.defaultAddress?.fullAddress ?? 
        (addresses.isNotEmpty ? addresses.first.fullAddress : '');
    addressController.text = selectedAddress;
    
    PerfumeModel? selectedPerfume = _perfumes.isNotEmpty ? _perfumes.first : null;
    PaymentMethodModel? selectedPayment = _paymentMethods.isNotEmpty
        ? (_paymentMethods.where((pm) => pm.isActive).isNotEmpty
            ? _paymentMethods.firstWhere((pm) => pm.isActive)
            : _paymentMethods.first)
        : null;
    bool isSubmitting = false;
    bool isDetectingLocation = false;
    bool useCustomAddress = addresses.isEmpty;
    int currentStep = 1; // 1 = Detail Pesanan, 2 = Metode Pembayaran

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final double subtotal = quantity * service.price;
            const int deliveryFee = 10000;
            final double grandTotal = subtotal + deliveryFee;
            final finalAddr = selectedAddress.trim().isNotEmpty
                ? selectedAddress.trim()
                : addressController.text.trim();
            final isCashSelected = selectedPayment == null ||
                selectedPayment!.code.toLowerCase().contains('cash') ||
                selectedPayment!.name.toLowerCase().contains('tunai') ||
                selectedPayment!.name.toLowerCase().contains('cod');
            final isQrisSelected = selectedPayment != null &&
                (selectedPayment!.code.toLowerCase().contains('qris') ||
                 selectedPayment!.name.toLowerCase().contains('qris'));

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
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
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header dengan Navigasi Step
                    Row(
                      children: [
                        if (currentStep == 2) ...[
                          IconButton(
                            icon: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.textPrimary),
                            onPressed: () => setModalState(() => currentStep = 1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Kembali ke detail pesanan',
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            currentStep == 1 ? service.icon : LucideIcons.creditCard,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentStep == 1 ? service.name : 'Pilih Pembayaran',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                currentStep == 1
                                    ? '${CurrencyFormatter.formatRupiah(service.price)} / ${service.unit} • Est. ${service.duration}'
                                    : 'Langkah 2 dari 2 • Konfirmasi Pesanan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: currentStep == 1 ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(modalContext),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Step Indicator Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: currentStep == 2 ? AppColors.primary : AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ==========================================
                    // STEP 1: DETAIL PESANAN & ALAMAT
                    // ==========================================
                    if (currentStep == 1) ...[
                      // Pickup Address
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alamat Penjemputan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: isDetectingLocation
                                ? null
                                : () async {
                                    setModalState(() => isDetectingLocation = true);
                                    final result = await LocationService.getCurrentLocationWithAddress(modalContext);
                                    setModalState(() {
                                      isDetectingLocation = false;
                                      if (result != null) {
                                        useCustomAddress = true;
                                        selectedAddress = result.fullAddress;
                                        addressController.text = result.fullAddress;
                                      }
                                    });
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDetectingLocation)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  else
                                    const Icon(LucideIcons.locateFixed, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDetectingLocation ? 'Mencari GPS...' : 'Gunakan GPS',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!useCustomAddress && addresses.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedAddress.isNotEmpty ? selectedAddress : addresses.first.fullAddress,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: addresses.map((a) {
                            return DropdownMenuItem<String>(
                              value: a.fullAddress,
                              child: Text(
                                '${a.label}: ${a.fullAddress}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedAddress = val;
                                addressController.text = val;
                              });
                            }
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: addressController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Masukkan atau deteksi alamat penjemputan...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: addresses.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.list, size: 16, color: AppColors.primary),
                                    tooltip: 'Pilih dari alamat tersimpan',
                                    onPressed: () {
                                      setModalState(() {
                                        useCustomAddress = false;
                                        selectedAddress = addresses.first.fullAddress;
                                        addressController.text = addresses.first.fullAddress;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => selectedAddress = val,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Quantity Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jumlah / Estimasi Berat',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                service.unit == 'kg' ? 'Disesuaikan saat timbang kurir' : 'Jumlah satuan',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: quantity > 1.0
                                    ? () => setModalState(() => quantity -= 1.0)
                                    : null,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surfaceVariant,
                                  foregroundColor: AppColors.textPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(LucideIcons.minus, size: 16),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${quantity.toInt()} ${service.unit}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: () => setModalState(() => quantity += 1.0),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Perfume Choice
                      if (_perfumes.isNotEmpty) ...[
                        const Text('Pilihan Parfum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<PerfumeModel>(
                          initialValue: selectedPerfume ?? _perfumes.first,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _perfumes.map((p) {
                            return DropdownMenuItem<PerfumeModel>(
                              value: p,
                              child: Text(
                                p.description.isNotEmpty ? '${p.name} (${p.description})' : p.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedPerfume = val),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Notes
                      const Text('Catatan Tambahan (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Pisahkan cucian putih / jemput sebelum jam 12...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price Breakdown
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Estimasi Layanan (${quantity.toInt()} ${service.unit})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.formatRupiah(subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ongkir Antar-Jemput', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.formatRupiah(deliveryFee), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Estimasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text(
                                  CurrencyFormatter.formatRupiah(grandTotal),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomButton(
                        text: 'Lanjut ke Pembayaran',
                        icon: LucideIcons.arrowRight,
                        onPressed: () {
                          if (finalAddr.isEmpty) {
                            AppToast.showError(modalContext, 'Silakan masukkan alamat penjemputan terlebih dahulu');
                            return;
                          }
                          setModalState(() => currentStep = 2);
                        },
                      ),
                    ],

                    // ==========================================
                    // STEP 2: METODE PEMBAYARAN & KONFIRMASI
                    // ==========================================
                    if (currentStep == 2) ...[
                      // Mini Order Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${quantity.toInt()} ${service.unit}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    finalAddr,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedPerfume != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(LucideIcons.sparkles, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Parfum: ${selectedPerfume!.name}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Pilih Metode Pembayaran',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),

                      // List Pilihan Metode Pembayaran
                      ..._paymentMethods.where((pm) => pm.isActive).map((pm) {
                        final isSelected = selectedPayment?.id == pm.id;
                        final isCash = pm.code.toLowerCase().contains('cash') ||
                            pm.name.toLowerCase().contains('tunai') ||
                            pm.name.toLowerCase().contains('cod');
                        final isQris = pm.code.toLowerCase().contains('qris') ||
                            pm.name.toLowerCase().contains('qris');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setModalState(() => selectedPayment = pm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.4) : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isCash
                                          ? LucideIcons.banknote
                                          : (isQris ? LucideIcons.qrCode : LucideIcons.creditCard),
                                      size: 16,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pm.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (pm.accountNumber != null && pm.accountNumber!.isNotEmpty)
                                          Text(
                                            '${pm.accountNumber}${pm.accountName != null && pm.accountName!.isNotEmpty ? ' • a/n ${pm.accountName}' : ''}',
                                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (pm.accountNumber != null && pm.accountNumber!.isNotEmpty && !isQris) ...[
                                    IconButton(
                                      icon: const Icon(LucideIcons.copy, size: 16, color: AppColors.primary),
                                      tooltip: 'Salin nomor rekening',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: pm.accountNumber!));
                                        AppToast.showSuccess(modalContext, 'Nomor rekening ${pm.accountNumber} berhasil disalin!');
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 18,
                                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),

                      // TAMPILAN DETAIL METODE PEMBAYARAN TERPILIH
                      if (selectedPayment != null) ...[
                        // 1. DETAIL QRIS (INFO PENJELASAN)
                        if (selectedPayment!.code.toLowerCase().contains('qris') ||
                            selectedPayment!.name.toLowerCase().contains('qris')) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11938).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE11938).withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE11938),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.qrCode, size: 12, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            'QRIS OTOMATIS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Verifikasi Otomatis Real-time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE11938),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Kode QRIS pembayaran akan otomatis ditampilkan setelah Anda menekan tombol "Bayar via QRIS Sekarang" di bawah.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(LucideIcons.scanLine, size: 13, color: AppColors.textSecondary),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Mendukung GoPay, OVO, DANA, BCA, Mandiri, BRI, ShopeePay, & Semua E-Wallet/Bank',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                        // 2. DETAIL TRANSFER BANK DENGAN TOMBOL SALIN
                        else if (selectedPayment!.accountNumber != null &&
                            selectedPayment!.accountNumber!.isNotEmpty &&
                            !selectedPayment!.code.toLowerCase().contains('cash') &&
                            !selectedPayment!.name.toLowerCase().contains('tunai') &&
                            !selectedPayment!.name.toLowerCase().contains('cod')) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.creditCard, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Detail Rekening Transfer ${selectedPayment!.name}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Nomor Rekening', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              selectedPayment!.accountNumber!,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (selectedPayment!.accountName != null && selectedPayment!.accountName!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'a/n ${selectedPayment!.accountName}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: selectedPayment!.accountNumber!));
                                          AppToast.showSuccess(modalContext, 'Nomor rekening ${selectedPayment!.accountNumber} berhasil disalin!');
                                        },
                                        icon: const Icon(LucideIcons.copy, size: 13, color: Colors.white),
                                        label: const Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Silakan transfer sesuai dengan total nominal pembayaran di bawah.',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ]
                        // 3. DETAIL TUNAI / COD
                        else if (selectedPayment!.code.toLowerCase().contains('cash') ||
                            selectedPayment!.name.toLowerCase().contains('tunai') ||
                            selectedPayment!.name.toLowerCase().contains('cod')) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.banknote, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pembayaran tunai dapat langsung diserahkan kepada kurir saat penjemputan atau pengantaran.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      // Price Breakdown Akhir
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Layanan (${quantity.toInt()} ${service.unit})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.formatRupiah(subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ongkir Antar-Jemput', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.formatRupiah(deliveryFee), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text(
                                  CurrencyFormatter.formatRupiah(grandTotal),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomButton(
                        text: !isCashSelected
                            ? (isQrisSelected ? 'Bayar via QRIS Sekarang' : 'Bayar via ${selectedPayment?.name ?? 'Xendit'} Sekarang')
                            : 'Konfirmasi Pesan Laundry',
                        icon: isQrisSelected
                            ? LucideIcons.qrCode
                            : (!isCashSelected ? LucideIcons.creditCard : LucideIcons.checkCheck),
                        isLoading: isSubmitting,
                        onPressed: () async {
                          if (finalAddr.isEmpty) {
                            AppToast.showError(modalContext, 'Silakan masukkan alamat penjemputan terlebih dahulu');
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            final paymentLabel = selectedPayment != null ? selectedPayment!.name : 'Tunai';
                            final paymentNote = 'Metode Pembayaran: $paymentLabel';
                            final perfumeNote = selectedPerfume != null ? 'Parfum: ${selectedPerfume!.name}' : '';
                            final userNote = noteController.text.trim();
                            
                            final noteParts = [
                              paymentNote,
                              if (perfumeNote.isNotEmpty) perfumeNote,
                              if (userNote.isNotEmpty) userNote,
                            ];
                            final fullNote = noteParts.join(' • ');

                            final newOrder = await _orderRepository.createOrder(
                              serviceName: service.name,
                              serviceType: service.categoryName.isNotEmpty ? service.categoryName : 'Layanan',
                              quantity: quantity,
                              unit: service.unit,
                              pricePerUnit: service.price,
                              pickupAddress: finalAddr,
                              deliveryAddress: finalAddr,
                              notes: fullNote,
                            );

                            if (modalContext.mounted) {
                              Navigator.pop(modalContext);
                            }

                            // 1. Jika QRIS, tampilkan Dynamic QRIS Sheet
                            if (isQrisSelected && context.mounted) {
                              try {
                                final paymentRepo = PaymentRepository();
                                final paymentResult = await paymentRepo.createXenditPayment(
                                  newOrder.id,
                                  paymentMethod: selectedPayment!.code,
                                );
                                if (context.mounted) {
                                  XenditQrisSheet.show(
                                    context,
                                    payment: paymentResult,
                                    paymentRepository: paymentRepo,
                                    onPaymentSuccess: () {
                                      if (context.mounted) {
                                        AppToast.showSuccess(
                                          context,
                                          'Pembayaran "${service.name}" (${paymentResult.paymentMethod}) berhasil terverifikasi!',
                                        );
                                      }
                                    },
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.showWarning(
                                    context,
                                    'Pesanan dibuat. Gagal menghubungkan ke Xendit: $e',
                                  );
                                }
                              }
                            }
                            // 2. Jika Transfer Bank Manual / Rekening, tampilkan Sheet Upload Bukti Transfer
                            else if (!isCashSelected && context.mounted) {
                              PaymentProofUploadSheet.show(
                                context,
                                orderId: newOrder.id,
                                invoiceNo: newOrder.invoiceNo,
                                totalAmount: grandTotal.toInt(),
                                bankName: selectedPayment?.name ?? '',
                                accountNumber: selectedPayment?.accountNumber ?? '',
                                accountName: selectedPayment?.accountName ?? '',
                                onUploadedSuccess: () {
                                  if (context.mounted) {
                                    AppToast.showSuccess(
                                      context,
                                      'Pesanan #${newOrder.invoiceNo} dibuat! Bukti transfer telah diterima & menunggu verifikasi admin.',
                                    );
                                  }
                                },
                              );
                            }
                            // 3. Jika Tunai / COD
                            else if (context.mounted) {
                              AppToast.showSuccess(
                                context,
                                'Pesanan "${service.name}" berhasil dijadwalkan! Kurir akan segera meluncur.',
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              AppToast.showError(context, 'Gagal membuat pesanan: $e');
                            }
                          }
                        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Katalog Layanan'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari layanan cuci, setrika, sepatu...',
                prefixIcon: const Icon(LucideIcons.search, color: AppColors.textMuted, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Category Filter Chips (Dynamic from backend)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip('Semua', ''),
                ..._categories
                    .where((c) => c.isActive)
                    .map((cat) => _buildCategoryChip(cat.name, cat.id)),
              ],
            ),
          ),

          // Services List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _services.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada layanan yang sesuai.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return ServiceCard(
                            service: service,
                            onOrderTap: () => _showBookingBottomSheet(context, service),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _onCategoryChanged(categoryId);
          }
        },
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
