import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/withdrawal_request_model.dart';
import '../../../../data/repositories/courier_repository.dart';

class CourierWithdrawalSheet extends StatefulWidget {
  final ICourierRepository courierRepository;
  final int currentBalance;
  final VoidCallback onSuccess;

  const CourierWithdrawalSheet({
    super.key,
    required this.courierRepository,
    required this.currentBalance,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ICourierRepository courierRepository,
    required int currentBalance,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: CourierWithdrawalSheet(
          courierRepository: courierRepository,
          currentBalance: currentBalance,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<CourierWithdrawalSheet> createState() => _CourierWithdrawalSheetState();
}

class _CourierWithdrawalSheetState extends State<CourierWithdrawalSheet> {
  int _activeTabIndex = 0; // 0: Form Pengajuan, 1: Riwayat WD
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  late int _availableBalance;
  String _selectedDestination = 'BCA';
  bool _isSubmitting = false;

  late Future<List<WithdrawalRequestModel>> _withdrawalsFuture;
  bool _isLoadingPaymentMethods = true;

  List<Map<String, dynamic>> _destinationOptions = [
    {'name': 'Bank BCA', 'code': 'BCA', 'type': 'bank'},
    {'name': 'Bank Mandiri', 'code': 'Mandiri', 'type': 'bank'},
    {'name': 'Bank BRI', 'code': 'BRI', 'type': 'bank'},
    {'name': 'Bank BNI', 'code': 'BNI', 'type': 'bank'},
    {'name': 'Bank BSI (Syariah)', 'code': 'BSI', 'type': 'bank'},
    {'name': 'GoPay', 'code': 'GoPay', 'type': 'ewallet'},
    {'name': 'OVO', 'code': 'OVO', 'type': 'ewallet'},
    {'name': 'DANA', 'code': 'DANA', 'type': 'ewallet'},
    {'name': 'ShopeePay', 'code': 'ShopeePay', 'type': 'ewallet'},
  ];

  @override
  void initState() {
    super.initState();
    _availableBalance = widget.currentBalance;
    _loadWithdrawals();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await widget.courierRepository.getPaymentMethods();
      if (!mounted) return;

      final List<Map<String, dynamic>> dynamicOptions = [];
      for (final pm in methods) {
        final codeLower = pm.code.toLowerCase();
        final nameLower = pm.name.toLowerCase();

        // Lewati metode yang bukan pembayaran rekening / transfer / ewallet (misal: tunai / cash)
        if (codeLower.contains('cash') ||
            codeLower.contains('tunai') ||
            nameLower.contains('tunai') ||
            codeLower.contains('pos') ||
            codeLower.contains('cod')) {
          continue;
        }

        final isEwallet = pm.type == 'ewallet' ||
            codeLower.contains('gopay') ||
            codeLower.contains('ovo') ||
            codeLower.contains('dana') ||
            codeLower.contains('shopeepay') ||
            codeLower.contains('linkaja');

        dynamicOptions.add({
          'name': pm.name,
          'code': pm.code.isNotEmpty ? pm.code : pm.name,
          'type': isEwallet ? 'ewallet' : 'bank',
        });
      }

      if (dynamicOptions.isNotEmpty) {
        setState(() {
          _destinationOptions = dynamicOptions;
          if (!_destinationOptions.any((opt) => opt['code'] == _selectedDestination)) {
            _selectedDestination = _destinationOptions.first['code'] as String;
          }
          _isLoadingPaymentMethods = false;
        });
      } else {
        setState(() => _isLoadingPaymentMethods = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPaymentMethods = false);
      }
    }
  }

  void _loadWithdrawals() {
    setState(() {
      _withdrawalsFuture = widget.courierRepository.getCourierWithdrawals();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _setQuickAmount(int val) {
    if (val > _availableBalance) {
      val = _availableBalance;
    }
    _amountController.text = val.toString();
    setState(() {});
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (rawAmount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal penarikan saldo adalah Rp 10.000'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (rawAmount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal penarikan melebihi saldo LaundryPay Anda saat ini'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await widget.courierRepository.requestWithdrawal(
        amount: rawAmount,
        bankName: _selectedDestination,
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        final remaining = (res['data']?['balance_remaining'] as num?)?.toInt() ?? (_availableBalance - rawAmount);
        _amountController.clear();
        setState(() {
          _availableBalance = remaining < 0 ? 0 : remaining;
          _activeTabIndex = 1;
          _loadWithdrawals();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengajuan penarikan ${CurrencyFormatter.formatRupiah(rawAmount)} berhasil dikirim! Menunggu verifikasi admin.',
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal mengajukan penarikan dana.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.arrowUpRight, color: Color(0xFF0284C7), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarik Dana (Withdrawal)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Pindahkan saldo tips ke rekening / e-wallet',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Tabs: Form Pengajuan vs Riwayat WD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTabIndex = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          'Form Tarik Dana',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _activeTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _activeTabIndex == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _activeTabIndex = 1);
                        _loadWithdrawals();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          'Riwayat Pengajuan WD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _activeTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _activeTabIndex == 1 ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body Content
          Expanded(
            child: _activeTabIndex == 0 ? _buildFormTab() : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saldo Tersedia Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Tersedia untuk Ditarik',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyFormatter.formatRupiah(_availableBalance),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_availableBalance >= 10000)
                    TextButton(
                      onPressed: () => _setQuickAmount(_availableBalance),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(20),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Tarik Semua',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pilih Bank / E-Wallet
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tujuan Rekening / E-Wallet *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (_isLoadingPaymentMethods)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _destinationOptions.any((opt) => opt['code'] == _selectedDestination)
                  ? _selectedDestination
                  : (_destinationOptions.isNotEmpty ? _destinationOptions.first['code'] as String : null),
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
              items: _destinationOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['code'] as String,
                  child: Text(
                    opt['name'] as String,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDestination = val);
              },
            ),

            const SizedBox(height: 14),

            // Nomor Rekening / No HP
            const Text(
              'Nomor Rekening / No. HP E-Wallet *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Contoh: 1234567890 atau 08123456789',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
                  return 'Nomor rekening/no HP wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Atas Nama Pemilik Rekening
            const Text(
              'Nama Pemilik Rekening / Akun *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _accountNameController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nama lengkap sesuai rekening / e-wallet',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
                  return 'Nama pemilik rekening wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Nominal Penarikan
            const Text(
              'Nominal Penarikan (Rp) *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
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
                  return 'Nominal penarikan wajib diisi';
                }
                final n = int.tryParse(val.trim());
                if (n == null || n < 10000) {
                  return 'Minimal penarikan adalah Rp 10.000';
                }
                if (n > _availableBalance) {
                  return 'Nominal melebihi saldo tersedia (${CurrencyFormatter.formatRupiah(_availableBalance)})';
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
                _buildNominalChip(20000, 'Rp 20.000'),
                _buildNominalChip(50000, 'Rp 50.000'),
                _buildNominalChip(100000, 'Rp 100.000'),
                if (_availableBalance > 0)
                  _buildNominalChip(_availableBalance, 'Semua Saldo'),
              ],
            ),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSubmitting || _availableBalance < 10000 ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Mengirim Pengajuan...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Text(
                        'Ajukan Penarikan Dana',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: Text(
                'Proses transfer akan ditinjau & dikirimkan oleh Admin ke rekening tujuan Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNominalChip(int amount, String label) {
    return InkWell(
      onTap: () => _setQuickAmount(amount),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<WithdrawalRequestModel>>(
      future: _withdrawalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 32),
                const SizedBox(height: 8),
                const Text('Gagal memuat riwayat pengajuan penarikan', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _loadWithdrawals,
                  child: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(LucideIcons.arrowUpRight, size: 32, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum Ada Pengajuan Penarikan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pengajuan penarikan dana Anda akan tercatat secara transparan di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadWithdrawals(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.border),
            itemBuilder: (context, index) {
              final req = list[index];
              return _buildHistoryItem(req);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(WithdrawalRequestModel req) {
    Color badgeBg;
    Color badgeColor;
    String badgeText;

    if (req.isCompleted) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeColor = const Color(0xFF166534);
      badgeText = 'Berhasil Ditransfer';
    } else if (req.isRejected) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeColor = const Color(0xFF991B1B);
      badgeText = 'Ditolak & Dikembalikan';
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFF92400E);
      badgeText = 'Menunggu Verifikasi Admin';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.formatRupiah(req.amount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.building2, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${req.bankName} - ${req.accountNumber} (a/n ${req.accountName})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (req.adminNotes != null && req.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: ${req.adminNotes}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
            ),
          ],
          if (req.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Diajukan: ${req.createdAt!.toLocal().day.toString().padLeft(2, '0')}/${req.createdAt!.toLocal().month.toString().padLeft(2, '0')}/${req.createdAt!.toLocal().year}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
