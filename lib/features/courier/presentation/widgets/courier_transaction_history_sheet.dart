import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/wallet_transaction_model.dart';
import '../../../../data/repositories/courier_repository.dart';

class CourierTransactionHistorySheet extends StatefulWidget {
  final ICourierRepository courierRepository;
  final int currentBalance;
  final int totalTips;

  const CourierTransactionHistorySheet({
    super.key,
    required this.courierRepository,
    this.currentBalance = 0,
    this.totalTips = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required ICourierRepository courierRepository,
    int currentBalance = 0,
    int totalTips = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourierTransactionHistorySheet(
        courierRepository: courierRepository,
        currentBalance: currentBalance,
        totalTips: totalTips,
      ),
    );
  }

  @override
  State<CourierTransactionHistorySheet> createState() =>
      _CourierTransactionHistorySheetState();
}

class _CourierTransactionHistorySheetState
    extends State<CourierTransactionHistorySheet> {
  late Future<List<WalletTransactionModel>> _transactionsFuture;
  String _selectedFilter = 'all'; // 'all', 'tip', 'other'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactionsFuture = widget.courierRepository.getCourierTransactions();
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year • $hour:$minute WIB';
  }

  List<WalletTransactionModel> _filterList(List<WalletTransactionModel> list) {
    if (_selectedFilter == 'tip') {
      return list.where((t) => t.category.toLowerCase() == 'tip').toList();
    } else if (_selectedFilter == 'other') {
      return list.where((t) => t.category.toLowerCase() != 'tip').toList();
    }
    return list;
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
                const Row(
                  children: [
                    Icon(LucideIcons.history, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Riwayat Transaksi & Saldo',
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
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Balance summary mini banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Tips Masuk',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatRupiah(widget.totalTips),
                        style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo LaundryPay',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatRupiah(widget.currentBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'Semua Transaksi'),
                const SizedBox(width: 8),
                _buildFilterChip('tip', 'Tips Pengantaran'),
                const SizedBox(width: 8),
                _buildFilterChip('other', 'Mutasi Lainnya'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // List of transactions
          Expanded(
            child: FutureBuilder<List<WalletTransactionModel>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'Gagal memuat riwayat transaksi',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _loadTransactions,
                            icon: const Icon(LucideIcons.refreshCw, size: 14),
                            label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rawList = snapshot.data ?? [];
                final list = _filterList(rawList);

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
                            child: const Icon(LucideIcons.receipt, size: 36, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Belum Ada Riwayat Transaksi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tips dari pelanggan dan mutasi saldo kurir Anda akan otomatis muncul di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    _loadTransactions();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const Divider(height: 12, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildTransactionTile(item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel item) {
    final isCredit = item.isCredit;
    final isTip = item.category.toLowerCase() == 'tip';

    Color iconColor;
    Color iconBg;
    IconData iconData;

    if (isTip) {
      iconColor = const Color(0xFF16A34A);
      iconBg = const Color(0xFFDCFCE7);
      iconData = LucideIcons.coins;
    } else if (item.category.toLowerCase() == 'topup') {
      iconColor = const Color(0xFF0284C7);
      iconBg = const Color(0xFFE0F2FE);
      iconData = LucideIcons.wallet;
    } else if (item.category.toLowerCase() == 'payment') {
      iconColor = const Color(0xFFEA580C);
      iconBg = const Color(0xFFFFEDD5);
      iconData = LucideIcons.shoppingBag;
    } else {
      iconColor = isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      iconBg = isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
      iconData = isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),

          // Title, description & date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (item.invoiceNo != null && item.invoiceNo!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Text(
                          item.invoiceNo!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _formatDateTime(item.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${CurrencyFormatter.formatRupiah(item.amount)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isCredit
                      ? const Color(0xFF22C55E).withAlpha(25)
                      : const Color(0xFFEF4444).withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCredit ? 'Masuk' : 'Keluar',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
