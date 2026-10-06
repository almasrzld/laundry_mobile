import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:laundry_app/core/constants/app_colors.dart';
import 'package:laundry_app/core/services/location_service.dart';
import 'package:laundry_app/core/services/session_manager.dart';
import 'package:laundry_app/core/utils/app_toast.dart';
import 'package:laundry_app/core/utils/currency_formatter.dart';
import 'package:laundry_app/core/widgets/custom_button.dart';
import 'package:laundry_app/data/models/master_model.dart';
import 'package:laundry_app/data/models/payment_model.dart';
import 'package:laundry_app/data/models/promo_model.dart';
import 'package:laundry_app/data/models/service_model.dart';
import 'package:laundry_app/data/models/user_model.dart';
import 'package:laundry_app/data/repositories/order_repository.dart';
import 'package:laundry_app/data/repositories/payment_repository.dart';
import 'package:laundry_app/data/repositories/promo_repository.dart';
import 'package:laundry_app/data/repositories/service_repository.dart';
import 'package:laundry_app/data/repositories/user_repository.dart';
import 'package:laundry_app/features/orders/presentation/widgets/payment_proof_upload_sheet.dart';
import 'package:laundry_app/features/profile/presentation/widgets/top_up_sheet.dart';
import 'package:laundry_app/features/services/presentation/widgets/xendit_qris_sheet.dart';

class OrderCheckoutSheet extends StatefulWidget {
  final ServiceModel service;
  final UserModel user;
  final PromoModel? initialPromo;
  final VoidCallback? onOrderSuccess;

  const OrderCheckoutSheet({
    super.key,
    required this.service,
    required this.user,
    this.initialPromo,
    this.onOrderSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ServiceModel service,
    required UserModel user,
    PromoModel? initialPromo,
    VoidCallback? onOrderSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OrderCheckoutSheet(
        service: service,
        user: user,
        initialPromo: initialPromo,
        onOrderSuccess: onOrderSuccess,
      ),
    );
  }

  @override
  State<OrderCheckoutSheet> createState() => _OrderCheckoutSheetState();
}

class _OrderCheckoutSheetState extends State<OrderCheckoutSheet> {
  final ServiceRepository _serviceRepo = ServiceRepository();
  final OrderRepository _orderRepo = OrderRepository();
  final UserRepository _userRepo = UserRepository();
  final PromoRepository _promoRepo = PromoRepository();

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _promoInputController = TextEditingController();

  late UserModel _currentUser;
  List<PerfumeModel> _perfumes = [];
  List<PaymentMethodModel> _paymentMethods = [];
  List<PromoModel> _availablePromos = [];

  double _quantity = 1.0;
  String _selectedAddress = '';
  double? _currentLat;
  double? _currentLng;
  bool _useCustomAddress = false;

  PerfumeModel? _selectedPerfume;
  PaymentMethodModel? _selectedPayment;
  PromoModel? _appliedPromo;

  // Dynamic Ongkir Calculation State
  CalculateOngkirResultModel? _ongkirResult;
  bool _isCalculatingOngkir = false;
  int _ongkirFee = 0;

  // Reward Points State
  bool _useRewardPoints = false;

  // Flow State
  int _currentStep = 1; // 1 = Detail & Ongkir, 2 = Promo, Poin & Pembayaran
  bool _isLoadingInit = true;
  bool _isDetectingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _appliedPromo = widget.initialPromo;

    final defaultAddr = _currentUser.defaultAddress?.fullAddress ??
        (_currentUser.addresses.isNotEmpty ? _currentUser.addresses.first.fullAddress : '');
    _selectedAddress = defaultAddr;
    _addressController.text = defaultAddr;
    _useCustomAddress = _currentUser.addresses.isEmpty;

    _initData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    _promoInputController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final perfumesFuture = _serviceRepo.getPerfumes().catchError((_) => <PerfumeModel>[]);
      final paymentsFuture = _serviceRepo.getPaymentMethods().catchError((_) => <PaymentMethodModel>[]);
      final eventPromosFuture = _promoRepo.getPromos(category: 'Event', activeOnly: true).catchError((_) => <PromoModel>[]);
      final userVouchersFuture = _userRepo.getUserVouchers(activeOnly: true).catchError((_) => <PromoModel>[]);
      final profileFuture = _userRepo.getProfile().catchError((_) => widget.user);

      final results = await Future.wait([
        perfumesFuture,
        paymentsFuture,
        eventPromosFuture,
        userVouchersFuture,
        profileFuture,
      ]);

      if (mounted) {
        setState(() {
          _perfumes = results[0] as List<PerfumeModel>;
          _paymentMethods = results[1] as List<PaymentMethodModel>;

          final eventPromos = results[2] as List<PromoModel>;
          final userVouchers = results[3] as List<PromoModel>;

          // Gabungkan event promos + user vouchers, hilangkan duplikat kode, saring yang masih valid
          final Map<String, PromoModel> combinedMap = {};
          for (final p in [...eventPromos, ...userVouchers]) {
            if (p.isValidPeriod && !p.isUsed) {
              combinedMap[p.code.toUpperCase()] = p;
            }
          }
          _availablePromos = combinedMap.values.toList();

          final refreshedUser = results[4] as UserModel?;
          if (refreshedUser != null && refreshedUser != UserModel.empty) {
            _currentUser = refreshedUser;
          }

          if (_perfumes.isNotEmpty) _selectedPerfume = _perfumes.first;

          final activePayments = _paymentMethods.where((p) => p.isActive).toList();
          if (activePayments.isNotEmpty && _selectedPayment == null) {
            _selectedPayment = activePayments.first;
          }

          _isLoadingInit = false;
        });

        _tryCalculateInitialOngkir();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingInit = false);
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final updated = await _userRepo.getProfile();
      if (updated != UserModel.empty && mounted) {
        setState(() {
          _currentUser = updated;
        });
      }
    } catch (_) {}
  }

  void _openTopUpSheet({int? prefillAmount, String? reason}) {
    TopUpSheet.show(
      context,
      user: _currentUser,
      prefillAmount: prefillAmount,
      prefillReason: reason,
      onTopUpSuccess: () {
        _refreshUserData();
      },
    );
  }

  Future<void> _tryCalculateInitialOngkir() async {
    // 1. Jika koordinat sudah ada (misal dari GPS), gunakan langsung
    if (_currentLat != null && _currentLng != null) {
      _fetchOngkirCalculation(_currentLat!, _currentLng!);
      return;
    }

    // 2. Jika ada alamat teks, lakukan forward geocoding secara otomatis
    final addrToGeocode = _selectedAddress.isNotEmpty ? _selectedAddress : _addressController.text;
    if (addrToGeocode.trim().isNotEmpty) {
      if (mounted) setState(() => _isCalculatingOngkir = true);
      final coords = await LocationService.geocodeAddress(addrToGeocode);
      if (coords != null && mounted) {
        _currentLat = coords['lat'];
        _currentLng = coords['lon'];
        _fetchOngkirCalculation(_currentLat!, _currentLng!);
        return;
      }
    }

    // 3. Fallback jika koordinat tidak ditemukan
    final lat = _currentLat ?? -7.55611;
    final lng = _currentLng ?? 110.77250;
    _fetchOngkirCalculation(lat, lng);
  }

  Future<void> _fetchOngkirCalculation(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isCalculatingOngkir = true);

    try {
      final result = await _serviceRepo.calculateOngkir(latitude: lat, longitude: lng);
      if (mounted) {
        setState(() {
          _ongkirResult = result;
          _isCalculatingOngkir = false;
          if (result != null) {
            _ongkirFee = result.isFree ? 0 : result.priceOngkir;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCalculatingOngkir = false);
      }
    }
  }

  // =========================================================================
  // FINANCIAL CALCULATIONS (Subtotal, Ongkir, Voucher, Poin, Grand Total)
  // =========================================================================
  double get _subtotal => _quantity * widget.service.price;

  int get _voucherDiscount {
    if (_appliedPromo == null) return 0;
    final promo = _appliedPromo!;

    // Cek tenggat waktu dan syarat minimal order
    if (promo.isExpired) return 0;
    if (promo.minOrderAmount > 0 && _subtotal < promo.minOrderAmount) {
      return 0;
    }

    // 1. Voucher Bebas Ongkir (Gratis Total Biaya Pengiriman)
    if (promo.isFreeDelivery) {
      return _ongkirFee;
    }

    // 2. Voucher Potongan Ongkir
    if (promo.isDeliveryDiscount) {
      if (promo.isPercentage) {
        final calc = (_ongkirFee * (promo.discountAmount / 100)).toInt();
        if (promo.maxDiscount != null && promo.maxDiscount! > 0) {
          return min(calc, min(promo.maxDiscount!, _ongkirFee));
        }
        return min(calc, _ongkirFee);
      } else {
        return min(promo.discountAmount, _ongkirFee);
      }
    }

    // 3. Voucher Potongan Harga Layanan (Cucian)
    if (promo.isServiceDiscount || promo.benefitType.isEmpty) {
      if (promo.isPercentage) {
        final calc = (_subtotal * (promo.discountAmount / 100)).toInt();
        if (promo.maxDiscount != null && promo.maxDiscount! > 0) {
          return min(calc, min(promo.maxDiscount!, _subtotal.toInt()));
        }
        return min(calc, _subtotal.toInt());
      } else {
        return min(promo.discountAmount, _subtotal.toInt());
      }
    }

    return 0;
  }

  int get _maxUsablePoints {
    final billBeforePoints = max(0, (_subtotal + _ongkirFee - _voucherDiscount).toInt());
    return min(_currentUser.rewardPoints, billBeforePoints);
  }

  int get _effectivePointDiscount {
    if (!_useRewardPoints) return 0;
    return _maxUsablePoints;
  }

  double get _grandTotal {
    final total = _subtotal + _ongkirFee - _voucherDiscount - _effectivePointDiscount;
    return max(0.0, total);
  }

  bool get _isFreeViaPromosAndPoints => _grandTotal == 0;

  // =========================================================================
  // PROMO MODAL SELECTOR
  // =========================================================================
  void _showPromoPickerModal() {
    _promoInputController.text = '';
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(LucideIcons.ticketPercent, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Pilih Voucher & Promo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Input Manual Kode Voucher
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoInputController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                            decoration: InputDecoration(
                              hintText: 'Ketik Kode Voucher',
                              hintStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, letterSpacing: 0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final code = _promoInputController.text.trim().toUpperCase();
                            if (code.isEmpty) return;

                            final PromoModel matched;
                            final localMatching = _availablePromos.where((p) => p.code.toUpperCase() == code).toList();
                            if (localMatching.isNotEmpty) {
                              matched = localMatching.first;
                            } else {
                              try {
                                matched = await _userRepo.verifyVoucher(code);
                              } catch (err) {
                                setSheetState(() {
                                  localError = 'Kode voucher "$code" tidak valid atau belum Anda tukarkan.';
                                });
                                return;
                              }
                            }

                            if (matched.isExpired) {
                              setSheetState(() {
                                localError = 'Voucher "$code" telah kedaluwarsa pada ${matched.formattedPeriod}.';
                              });
                              return;
                            }

                            if (matched.minOrderAmount > 0 && _subtotal < matched.minOrderAmount) {
                              setSheetState(() {
                                localError = 'Minimal belanja ${CurrencyFormatter.formatRupiah(matched.minOrderAmount)} untuk menggunakan voucher ini.';
                              });
                              return;
                            }

                            if (mounted && context.mounted) {
                              setState(() => _appliedPromo = matched);
                              Navigator.pop(sheetCtx);
                              AppToast.showSuccess(context, 'Voucher "${matched.code}" berhasil dipasang!');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Terapkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 6),
                      Text(localError!, style: const TextStyle(fontSize: 11, color: Color(0xFFE11D48), fontWeight: FontWeight.w500)),
                    ],
                    const Divider(height: 24),

                    // List Voucher Tersedia
                    const Text('Voucher Tersedia Untuk Anda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),

                    if (_availablePromos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(LucideIcons.ticket, size: 36, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'Belum Ada Voucher Siap Pakai',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tukarkan Poin Rewards di profil Anda atau gunakan voucher promo event yang tersedia.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._availablePromos.map((promo) {
                        final isEligible = promo.minOrderAmount == 0 || _subtotal >= promo.minOrderAmount;
                        final isCurrentlyApplied = _appliedPromo?.code == promo.code;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isEligible
                                ? () {
                                    setState(() => _appliedPromo = promo);
                                    Navigator.pop(sheetCtx);
                                    if (mounted) {
                                      AppToast.showSuccess(context, 'Voucher "${promo.code}" aktif!');
                                    }
                                  }
                                : () {
                                    setSheetState(() {
                                      localError = 'Minimal belanja ${CurrencyFormatter.formatRupiah(promo.minOrderAmount)} untuk voucher ini.';
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentlyApplied
                                    ? AppColors.primaryLight.withValues(alpha: 0.4)
                                    : (isEligible ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrentlyApplied
                                      ? AppColors.primary
                                      : (isEligible ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                  width: isCurrentlyApplied ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isEligible ? promo.color.withValues(alpha: 0.15) : AppColors.textMuted.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(promo.icon, size: 20, color: isEligible ? promo.color : AppColors.textMuted),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                promo.title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isEligible ? AppColors.textPrimary : AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: promo.isFreeDelivery
                                                    ? const Color(0xFFECFDF5)
                                                    : promo.isRewardPoint
                                                        ? const Color(0xFFFEF3C7)
                                                        : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                promo.discountLabel,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: promo.isFreeDelivery
                                                      ? const Color(0xFF059669)
                                                      : promo.isRewardPoint
                                                          ? const Color(0xFFD97706)
                                                          : AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (promo.subtitle.isNotEmpty)
                                          Text(
                                            promo.subtitle,
                                            style: TextStyle(fontSize: 11, color: isEligible ? AppColors.textSecondary : AppColors.textMuted),
                                          ),
                                        Row(
                                          children: [
                                            if (promo.minOrderAmount > 0)
                                              Text(
                                                'Min. order ${CurrencyFormatter.formatRupiah(promo.minOrderAmount)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isEligible ? AppColors.primary : Colors.amber.shade800,
                                                ),
                                              ),
                                            if (promo.formattedPeriod.isNotEmpty) ...[
                                              if (promo.minOrderAmount > 0)
                                                const Text(' • ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                              Text(
                                                'Berlaku s/d ${promo.endDate != null ? promo.formattedPeriod.split(' - ').last : ''}',
                                                style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isCurrentlyApplied)
                                    const Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 18)
                                  else if (isEligible)
                                    const Text('Pakai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))
                                  else
                                    const Text('Tidak Syarat', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // SUBMIT ORDER
  // =========================================================================
  Future<void> _handleConfirmOrder() async {
    final finalAddr = _selectedAddress.trim().isNotEmpty
        ? _selectedAddress.trim()
        : _addressController.text.trim();

    if (finalAddr.isEmpty) {
      if (mounted) {
        AppToast.showError(context, 'Silakan masukkan alamat penjemputan terlebih dahulu');
      }
      return;
    }

    if (_ongkirResult != null && !_ongkirResult!.isDeliverable) {
      if (mounted) {
        AppToast.showError(context, 'Lokasi alamat penjemputan di luar jangkauan pengantaran Almas Laundry');
      }
      return;
    }

    final isCashSelected = _selectedPayment == null ||
        _selectedPayment!.code.toLowerCase().contains('cash') ||
        _selectedPayment!.name.toLowerCase().contains('tunai') ||
        _selectedPayment!.name.toLowerCase().contains('cod');
    final isQrisSelected = _selectedPayment != null &&
        (_selectedPayment!.code.toLowerCase().contains('qris') ||
         _selectedPayment!.name.toLowerCase().contains('qris'));
    final isLaundryPay = _selectedPayment != null &&
        (_selectedPayment!.code.toLowerCase().contains('laundrypay') ||
         _selectedPayment!.name.toLowerCase().contains('saldo'));

    if (isLaundryPay && !_isFreeViaPromosAndPoints) {
      if (_currentUser.laundryPayBalance < _grandTotal) {
        final shortage = (_grandTotal - _currentUser.laundryPayBalance).toInt();
        if (mounted) {
          AppToast.showError(
            context,
            'Saldo LaundryPay Anda tidak mencukupi! Kurang ${CurrencyFormatter.formatRupiah(shortage)} dari total tagihan ${CurrencyFormatter.formatRupiah(_grandTotal)}. Silakan isi saldo terlebih dahulu.',
          );
          _openTopUpSheet(
            prefillAmount: shortage,
            reason: 'Kekurangan pembayaran pesanan ${widget.service.name} (${CurrencyFormatter.formatRupiah(shortage)})',
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final paymentLabel = _isFreeViaPromosAndPoints
          ? 'Lunas (Voucher & Poin)'
          : (_selectedPayment?.name ?? 'Tunai');

      final List<String> noteSegments = [
        'Metode Pembayaran: $paymentLabel',
        if (_ongkirResult != null)
          'Ongkir: ${CurrencyFormatter.formatRupiah(_ongkirFee)} (${_ongkirResult!.tierLabel} • ${_ongkirResult!.distance.toStringAsFixed(1)} km)',
        if (_appliedPromo != null && _voucherDiscount > 0)
          'Voucher: ${_appliedPromo!.code} (-${CurrencyFormatter.formatRupiah(_voucherDiscount)})',
        if (_useRewardPoints && _effectivePointDiscount > 0)
          'Poin Ditukar: $_effectivePointDiscount Pts (-${CurrencyFormatter.formatRupiah(_effectivePointDiscount)})',
        if (_selectedPerfume != null) 'Parfum: ${_selectedPerfume!.name}',
        if (_noteController.text.trim().isNotEmpty) _noteController.text.trim(),
      ];

      final fullNote = noteSegments.join(' • ');

      final newOrder = await _orderRepo.createOrder(
        serviceName: widget.service.name,
        serviceType: widget.service.categoryName.isNotEmpty ? widget.service.categoryName : 'Layanan',
        quantity: _quantity,
        unit: widget.service.unit,
        pricePerUnit: widget.service.price,
        deliveryFee: _ongkirFee,
        discount: _voucherDiscount,
        voucherCode: _appliedPromo?.code,
        pointsRedeemed: _useRewardPoints ? _effectivePointDiscount : 0,
        paymentMethod: _isFreeViaPromosAndPoints ? 'Voucher & Poin' : _selectedPayment?.name,
        paymentMethodCode: _isFreeViaPromosAndPoints ? 'FREE_PROMO' : _selectedPayment?.code,
        pickupAddress: finalAddr,
        deliveryAddress: finalAddr,
        notes: fullNote,
      );

      // Pre-fetch QRIS payment result BEFORE popping the sheet if QRIS is selected
      XenditPaymentResultModel? qrisPaymentResult;
      final paymentRepo = PaymentRepository();
      if (isQrisSelected && !_isFreeViaPromosAndPoints) {
        try {
          qrisPaymentResult = await paymentRepo.createXenditPayment(
            newOrder.id,
            paymentMethod: _selectedPayment!.code,
          );
        } catch (e) {
          debugPrint('Gagal generate QRIS Xendit: $e');
        }
      }

      if (!mounted) return;

      // Close this checkout bottom sheet
      Navigator.pop(context);
      widget.onOrderSuccess?.call();

      final targetContext = SessionManager.navigatorKey.currentContext;

      // 1. Jika Lunas via Voucher & Poin
      if (_isFreeViaPromosAndPoints) {
        if (targetContext != null && targetContext.mounted) {
          AppToast.showSuccess(
            targetContext,
            'Pesanan "${widget.service.name}" berhasil dibuat (Gratis via Promo & Poin)! Kurir akan segera menjemput.',
          );
        }
      }
      // 2. Jika QRIS Otomatis
      else if (isQrisSelected) {
        if (qrisPaymentResult != null && targetContext != null && targetContext.mounted) {
          XenditQrisSheet.show(
            targetContext,
            payment: qrisPaymentResult,
            paymentRepository: paymentRepo,
            onPaymentSuccess: () {
              final rootCtx = SessionManager.navigatorKey.currentContext;
              if (rootCtx != null && rootCtx.mounted) {
                AppToast.showSuccess(
                  rootCtx,
                  'Pembayaran "${widget.service.name}" berhasil terverifikasi otomatis!',
                );
              }
            },
          );
        } else if (targetContext != null && targetContext.mounted) {
          AppToast.showWarning(
            targetContext,
            'Pesanan #${newOrder.invoiceNo} dibuat. Menunggu pembayaran QRIS.',
          );
        }
      }
      // 3. Jika Transfer Bank Manual
      else if (!isCashSelected && !isLaundryPay) {
        if (targetContext != null && targetContext.mounted) {
          PaymentProofUploadSheet.show(
            targetContext,
            orderId: newOrder.id,
            invoiceNo: newOrder.invoiceNo,
            totalAmount: _grandTotal.toInt(),
            bankName: _selectedPayment?.name ?? '',
            accountNumber: _selectedPayment?.accountNumber ?? '',
            accountName: _selectedPayment?.accountName ?? '',
            onUploadedSuccess: () {
              final rootCtx = SessionManager.navigatorKey.currentContext;
              if (rootCtx != null && rootCtx.mounted) {
                AppToast.showSuccess(
                  rootCtx,
                  'Pesanan #${newOrder.invoiceNo} dibuat! Bukti transfer diterima.',
                );
              }
            },
          );
        }
      }
      // 4. Jika LaundryPay
      else if (isLaundryPay) {
        if (targetContext != null && targetContext.mounted) {
          AppToast.showSuccess(
            targetContext,
            'Pesanan "${widget.service.name}" berhasil dibayar menggunakan Saldo LaundryPay! Kurir akan segera menjemput.',
          );
        }
      }
      // 5. Jika Tunai
      else {
        if (targetContext != null && targetContext.mounted) {
          AppToast.showSuccess(
            targetContext,
            'Pesanan "${widget.service.name}" berhasil dijadwalkan! Kurir akan segera meluncur.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.showError(context, 'Gagal membuat pesanan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInit) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isCashSelected = _selectedPayment == null ||
        _selectedPayment!.code.toLowerCase().contains('cash') ||
        _selectedPayment!.name.toLowerCase().contains('tunai') ||
        _selectedPayment!.name.toLowerCase().contains('cod');
    final isQrisSelected = _selectedPayment != null &&
        (_selectedPayment!.code.toLowerCase().contains('qris') ||
         _selectedPayment!.name.toLowerCase().contains('qris'));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
            const SizedBox(height: 14),

            // Header dengan Step Navigation
            Row(
              children: [
                if (_currentStep == 2) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.textPrimary),
                    onPressed: () => setState(() => _currentStep = 1),
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
                    _currentStep == 1 ? widget.service.icon : LucideIcons.creditCard,
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
                        _currentStep == 1 ? widget.service.name : 'Promo, Poin & Pembayaran',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        _currentStep == 1
                            ? '${CurrencyFormatter.formatRupiah(widget.service.price)} / ${widget.service.unit} • Est. ${widget.service.duration}'
                            : 'Langkah 2 dari 2 • Rincian Total Akhir',
                        style: TextStyle(
                          fontSize: 11,
                          color: _currentStep == 1 ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Step Indicator Bar
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
                      color: _currentStep == 2 ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ===============================================================
            // STEP 1: DETAIL PESANAN, JUMLAH & ALAMAT (DENGAN ONGKIR OTOMATIS)
            // ===============================================================
            if (_currentStep == 1) ...[
              // 1. Alamat Penjemputan & GPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Alamat Penjemputan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _isDetectingLocation
                        ? null
                        : () async {
                            setState(() => _isDetectingLocation = true);
                            final loc = await LocationService.getCurrentLocationWithAddress(context);
                            setState(() {
                              _isDetectingLocation = false;
                              if (loc != null) {
                                _useCustomAddress = true;
                                _selectedAddress = loc.fullAddress;
                                _addressController.text = loc.fullAddress;
                                _currentLat = loc.latitude;
                                _currentLng = loc.longitude;
                              }
                            });
                            if (loc != null) {
                              _fetchOngkirCalculation(loc.latitude, loc.longitude);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDetectingLocation)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          else
                            const Icon(LucideIcons.locateFixed, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            _isDetectingLocation ? 'Mencari GPS...' : 'Gunakan GPS',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_useCustomAddress && _currentUser.addresses.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedAddress.isNotEmpty ? _selectedAddress : _currentUser.addresses.first.fullAddress,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: _currentUser.addresses.map((a) {
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
                      setState(() {
                        _selectedAddress = val;
                        _addressController.text = val;
                        _currentLat = null;
                        _currentLng = null;
                      });
                      _tryCalculateInitialOngkir();
                    }
                  },
                ),
              ] else ...[
                TextField(
                  controller: _addressController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ketik alamat penjemputan...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _currentUser.addresses.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.list, size: 16, color: AppColors.primary),
                            tooltip: 'Pilih dari alamat tersimpan',
                            onPressed: () {
                              setState(() {
                                _useCustomAddress = false;
                                _selectedAddress = _currentUser.addresses.first.fullAddress;
                                _addressController.text = _currentUser.addresses.first.fullAddress;
                                _currentLat = null;
                                _currentLng = null;
                              });
                              _tryCalculateInitialOngkir();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    _selectedAddress = val;
                    _currentLat = null;
                    _currentLng = null;
                  },
                  onSubmitted: (val) {
                    _selectedAddress = val;
                    _currentLat = null;
                    _currentLng = null;
                    _tryCalculateInitialOngkir();
                  },
                ),
              ],
              const SizedBox(height: 14),

              // 2. Dynamic Ongkir Live Info Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _ongkirFee == 0
                      ? const Color(0xFFECFDF5)
                      : AppColors.primaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _ongkirFee == 0
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _ongkirFee == 0 ? LucideIcons.truck : LucideIcons.mapPin,
                      size: 16,
                      color: _ongkirFee == 0 ? const Color(0xFF059669) : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _ongkirFee == 0 ? 'Gratis Ongkir Antar-Jemput' : 'Tarif Ongkir Terkalkulasi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _ongkirFee == 0 ? const Color(0xFF065F46) : AppColors.primary,
                                ),
                              ),
                              if (_isCalculatingOngkir) ...[
                                const SizedBox(width: 6),
                                const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                              ],
                            ],
                          ),
                          Text(
                            _ongkirResult != null
                                ? '${_ongkirResult!.tierLabel} • ${_ongkirResult!.distance.toStringAsFixed(1)} ${_ongkirResult!.unit?.codeUnit ?? "km"} dari outlet'
                                : 'Radius otomatis dihitung dari koordinat outlet terdekat',
                            style: TextStyle(
                              fontSize: 10,
                              color: _ongkirFee == 0 ? const Color(0xFF047857) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _ongkirFee == 0 ? 'Rp 0' : CurrencyFormatter.formatRupiah(_ongkirFee),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _ongkirFee == 0 ? const Color(0xFF059669) : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Jumlah / Berat Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumlah / Estimasi Berat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        widget.service.unit == 'kg' ? 'Disesuaikan saat timbang kurir' : 'Jumlah satuan',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _quantity > 1.0 ? () => setState(() => _quantity -= 1.0) : null,
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
                          '${_quantity.toInt()} ${widget.service.unit}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () => setState(() => _quantity += 1.0),
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

              // 4. Pilihan Parfum
              if (_perfumes.isNotEmpty) ...[
                const Text('Pilihan Parfum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<PerfumeModel>(
                  initialValue: _selectedPerfume ?? _perfumes.first,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                  onChanged: (val) => setState(() => _selectedPerfume = val),
                ),
                const SizedBox(height: 14),
              ],

              // 5. Catatan Tambahan
              const Text('Catatan Tambahan (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Pisahkan cucian putih / jemput sebelum jam 12...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown Step 1
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
                        Text('Estimasi Layanan (${_quantity.toInt()} ${widget.service.unit})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.formatRupiah(_subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ongkir Antar-Jemput', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          _ongkirFee == 0 ? 'Gratis (Rp 0)' : CurrencyFormatter.formatRupiah(_ongkirFee),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ongkirFee == 0 ? const Color(0xFF059669) : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Estimasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text(
                          CurrencyFormatter.formatRupiah(_subtotal + _ongkirFee),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CustomButton(
                text: 'Lanjut ke Promo & Pembayaran',
                icon: LucideIcons.arrowRight,
                onPressed: () {
                  final finalAddr = _selectedAddress.trim().isNotEmpty
                      ? _selectedAddress.trim()
                      : _addressController.text.trim();
                  if (finalAddr.isEmpty) {
                    AppToast.showError(context, 'Silakan masukkan alamat penjemputan terlebih dahulu');
                    return;
                  }
                  setState(() => _currentStep = 2);
                },
              ),
            ],

            // ===============================================================
            // STEP 2: VOUCHER PROMO, POIN REWARD, METODE PEMBAYARAN & SUBMIT
            // ===============================================================
            if (_currentStep == 2) ...[
              // 1. Voucher Promo Card (Connect to Promo & Grand Total)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _appliedPromo != null
                      ? AppColors.primaryLight.withValues(alpha: 0.35)
                      : AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _appliedPromo != null ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _appliedPromo != null ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.ticketPercent,
                        size: 18,
                        color: _appliedPromo != null ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _appliedPromo != null ? 'Voucher: ${_appliedPromo!.code}' : 'Voucher & Promo Diskon',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            _appliedPromo != null
                                ? 'Hemat ${CurrencyFormatter.formatRupiah(_voucherDiscount)}'
                                : 'Gunakan voucher untuk potongan harga / bebas ongkir',
                            style: TextStyle(
                              fontSize: 10,
                              color: _appliedPromo != null ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: _appliedPromo != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_appliedPromo != null)
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFFE11D48)),
                        onPressed: () => setState(() => _appliedPromo = null),
                        tooltip: 'Hapus Voucher',
                      )
                    else
                      TextButton(
                        onPressed: _showPromoPickerModal,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Pakai Promo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Tukarkan Poin Reward (Connect to Loyalty Point Balance & Grand Total)
              if (_currentUser.rewardPoints > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _useRewardPoints
                        ? const Color(0xFFFEF3C7)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useRewardPoints ? const Color(0xFFF59E0B) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.star, size: 18, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tukarkan Poin Reward',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Saldo Poin: ${_currentUser.rewardPoints} Pts (1 Pts = Rp 1)',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                            if (_useRewardPoints)
                              Text(
                                'Potongan -${CurrencyFormatter.formatRupiah(_effectivePointDiscount)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useRewardPoints,
                        activeTrackColor: const Color(0xFFD97706),
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setState(() => _useRewardPoints = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 3. Pilihan Metode Pembayaran
              const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),

              if (_isFreeViaPromosAndPoints) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, color: Color(0xFF059669), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lunas Penuh (Gratis)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                            Text(
                              'Total pesanan Rp 0 karena tertutup penuh oleh voucher dan poin reward.',
                              style: TextStyle(fontSize: 10, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // List Payment Methods
                ..._paymentMethods.where((pm) => pm.isActive).map((pm) {
                  final isSelected = _selectedPayment?.id == pm.id;
                  final isCash = pm.code.toLowerCase().contains('cash') ||
                      pm.name.toLowerCase().contains('tunai') ||
                      pm.name.toLowerCase().contains('cod');
                  final isQris = pm.code.toLowerCase().contains('qris') ||
                      pm.name.toLowerCase().contains('qris');
                  final isLaundryPay = pm.code.toLowerCase().contains('laundrypay') ||
                      pm.name.toLowerCase().contains('saldo');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedPayment = pm),
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
                                    : (isQris
                                        ? LucideIcons.qrCode
                                        : (isLaundryPay ? LucideIcons.wallet : LucideIcons.creditCard)),
                                size: 16,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        pm.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isLaundryPay) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${CurrencyFormatter.formatRupiah(_currentUser.laundryPayBalance)})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _currentUser.laundryPayBalance >= _grandTotal
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFE11D48),
                                          ),
                                        ),
                                      ],
                                    ],
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
                                  AppToast.showSuccess(context, 'Nomor rekening ${pm.accountNumber} berhasil disalin!');
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

                // LaundryPay Balance & Shortage Box
                if (!_isFreeViaPromosAndPoints && _selectedPayment != null &&
                    (_selectedPayment!.code.toLowerCase().contains('laundrypay') ||
                     _selectedPayment!.name.toLowerCase().contains('saldo'))) ...[
                  Builder(
                    builder: (ctx) {
                      final currentBal = _currentUser.laundryPayBalance;
                      final requiredTotal = _grandTotal.toInt();
                      final isShort = currentBal < requiredTotal;
                      final shortage = requiredTotal - currentBal;

                      if (isShort) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDA4AF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.alertTriangle, color: Color(0xFFE11D48), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Saldo LaundryPay Kurang ${CurrencyFormatter.formatRupiah(shortage)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFBE123C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Saldo Anda saat ini ${CurrencyFormatter.formatRupiah(currentBal)}, kurang ${CurrencyFormatter.formatRupiah(shortage)} dari total tagihan ${CurrencyFormatter.formatRupiah(requiredTotal)}. Silakan lakukan top-up saldo terlebih dahulu.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9F1239), height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 36,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openTopUpSheet(
                                      prefillAmount: shortage,
                                      reason: 'Kekurangan pembayaran pesanan ${widget.service.name} sebesar ${CurrencyFormatter.formatRupiah(shortage)}',
                                    );
                                  },
                                  icon: const Icon(LucideIcons.plusCircle, size: 14),
                                  label: Text(
                                    'Top-Up Saldo Sekarang (+${CurrencyFormatter.formatRupiah(shortage)})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE11D48),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6EE7B7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.checkCircle2, color: Color(0xFF059669), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Saldo LaundryPay Mencukupi',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Saldo aktif: ${CurrencyFormatter.formatRupiah(currentBal)} • Sisa setelah bayar: ${CurrencyFormatter.formatRupiah(currentBal - requiredTotal)}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
              const SizedBox(height: 10),

              // 4. Live Rincian Akhir Pembayaran
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
                        Text('Layanan (${_quantity.toInt()} ${widget.service.unit})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.formatRupiah(_subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ongkir Antar-Jemput', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          _ongkirFee == 0 ? 'Rp 0 (Gratis)' : CurrencyFormatter.formatRupiah(_ongkirFee),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ongkirFee == 0 ? const Color(0xFF059669) : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (_appliedPromo != null && _voucherDiscount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Voucher Diskon (${_appliedPromo!.code})', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          Text('-${CurrencyFormatter.formatRupiah(_voucherDiscount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ],
                    if (_useRewardPoints && _effectivePointDiscount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tukar Poin ($_effectivePointDiscount Pts)', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                          Text('-${CurrencyFormatter.formatRupiah(_effectivePointDiscount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                    ],
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text(
                          CurrencyFormatter.formatRupiah(_grandTotal),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CustomButton(
                text: _isFreeViaPromosAndPoints
                    ? 'Konfirmasi Pesan (Gratis)'
                    : (!isCashSelected
                        ? (isQrisSelected ? 'Bayar via QRIS Sekarang' : 'Bayar via ${_selectedPayment?.name ?? 'Xendit'} Sekarang')
                        : 'Konfirmasi Pesan Laundry'),
                icon: _isFreeViaPromosAndPoints
                    ? LucideIcons.checkCheck
                    : (isQrisSelected
                        ? LucideIcons.qrCode
                        : (!isCashSelected ? LucideIcons.creditCard : LucideIcons.checkCheck)),
                isLoading: _isSubmitting,
                onPressed: _handleConfirmOrder,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
