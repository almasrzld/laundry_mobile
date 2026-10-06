import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/launcher_helper.dart';
import '../../../../data/models/courier_summary_model.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/repositories/courier_repository.dart';
import '../../../orders/presentation/pages/order_detail_page.dart';
import '../widgets/courier_transaction_history_sheet.dart';
import '../widgets/courier_withdrawal_sheet.dart';

class CourierTasksPage extends StatefulWidget {
  const CourierTasksPage({super.key});

  @override
  State<CourierTasksPage> createState() => _CourierTasksPageState();
}

class _CourierTasksPageState extends State<CourierTasksPage> with SingleTickerProviderStateMixin {
  final ICourierRepository _courierRepository = CourierRepository();
  late TabController _tabController;

  void _showTransactionHistorySheet() {
    CourierTransactionHistorySheet.show(
      context,
      courierRepository: _courierRepository,
      currentBalance: _summary?.laundryPayBalance ?? 0,
      totalTips: _summary?.totalTips ?? 0,
    );
  }

  void _showWithdrawalSheet() {
    CourierWithdrawalSheet.show(
      context,
      courierRepository: _courierRepository,
      currentBalance: _summary?.laundryPayBalance ?? 0,
      onSuccess: _loadData,
    );
  }

  bool _isLoading = true;
  CourierSummaryModel? _summary;
  List<OrderModel> _activeTasks = [];
  List<OrderModel> _historyTasks = [];
  List<MasterOrderStatusModel> _masterStatuses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final summaryFuture = _courierRepository.getCourierSummary();
      final activeFuture = _courierRepository.getCourierTasks(status: 'active');
      final historyFuture = _courierRepository.getCourierTasks(status: 'history');
      final statusesFuture = _courierRepository.getMasterStatuses();

      final results = await Future.wait([summaryFuture, activeFuture, historyFuture, statusesFuture]);

      if (mounted) {
        setState(() {
          _summary = results[0] as CourierSummaryModel?;
          _activeTasks = results[1] as List<OrderModel>;
          _historyTasks = results[2] as List<OrderModel>;
          _masterStatuses = results[3] as List<MasterOrderStatusModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<MasterOrderStatusModel> _getCourierJobStatuses(OrderModel task) {
    if (_masterStatuses.isEmpty) return [];

    final currentCode = task.status.toApiString().toLowerCase();
    final currentName = task.statusName.toLowerCase();

    final isPickupStage = currentCode.contains('jemput') ||
        currentName.contains('jemput') ||
        currentCode.contains('menunggu') ||
        currentName.contains('menunggu');

    final isDeliveryStage = currentCode.contains('antar') ||
        currentName.contains('antar') ||
        currentCode.contains('siap') ||
        currentName.contains('siap') ||
        currentCode.contains('selesai') ||
        currentName.contains('selesai');

    List<MasterOrderStatusModel> allowed = [];

    if (isPickupStage) {
      // Tugas Penjemputan: Kurir sedang menjemput atau telah menyerahkan cucian ke workshop
      allowed = _masterStatuses.where((st) {
        final code = st.code.toLowerCase();
        return code == 'sedang-dijemput' || code == 'sedang-dicuci';
      }).toList();
    } else if (isDeliveryStage) {
      // Tugas Pengantaran: Kurir mengantar cucian bersih atau pesanan selesai
      allowed = _masterStatuses.where((st) {
        final code = st.code.toLowerCase();
        return code == 'siap-diantar' || code == 'pesanan-selesai';
      }).toList();
    }

    if (allowed.isEmpty) {
      allowed = _masterStatuses.where((st) {
        final code = st.code.toLowerCase();
        return code == 'sedang-dijemput' ||
            code == 'sedang-dicuci' ||
            code == 'siap-diantar' ||
            code == 'pesanan-selesai';
      }).toList();
    }

    return allowed;
  }

  Future<void> _updateStatus(OrderModel task, MasterOrderStatusModel status) async {
    final ok = await _courierRepository.updateTaskStatus(task.id, status.name);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status pesanan #${task.invoiceNo} berhasil diperbarui: ${status.name}'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui status. Anda hanya dapat memperbarui tugas pesanan milik Anda.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showStatusDialog(OrderModel task) {
    final availableStatuses = _getCourierJobStatuses(task);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Perbarui Status Tugas Kurir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Pesanan #${task.invoiceNo}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (availableStatuses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Tidak ada status tugas kurir yang tersedia untuk tahap ini',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableStatuses.length,
                      itemBuilder: (context, index) {
                        final st = availableStatuses[index];
                        return _buildStatusOption(ctx, task, st);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(BuildContext ctx, OrderModel task, MasterOrderStatusModel status) {
    final isCurrent = task.statusName.toLowerCase().trim() == status.name.toLowerCase().trim();

    Color statusColor = AppColors.primary;
    if (status.colorHex != null && status.colorHex!.isNotEmpty) {
      try {
        final hex = status.colorHex!.replaceAll('#', '');
        statusColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent ? statusColor : AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.check,
          color: isCurrent ? Colors.white : AppColors.textSecondary,
          size: 16,
        ),
      ),
      title: Text(
        status.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
          color: isCurrent ? statusColor : AppColors.textPrimary,
        ),
      ),
      subtitle: status.description != null && status.description!.isNotEmpty
          ? Text(status.description!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
          : null,
      onTap: () {
        Navigator.pop(ctx);
        _updateStatus(task, status);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Menu Kurir & Tips',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.primary, size: 20),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // 1. Performance & Tips Banner Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildSummaryCard(),
                    ),
                  ),

                  // 2. Tab Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppColors.textPrimary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                          tabs: [
                            Tab(text: 'Tugas Aktif (${_activeTasks.length})'),
                            Tab(text: 'Selesai & Tips (${_historyTasks.length})'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Tab Content
                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(_activeTasks, isActive: true),
                        _buildTaskList(_historyTasks, isActive: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final totalTips = _summary?.totalTips ?? 0;
    final rating = _summary?.averageRating ?? 0.0;
    final completed = _summary?.completedDeliveries ?? 0;
    final balance = _summary?.laundryPayBalance ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.truck, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Performa & Tips Kurir',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              if (rating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.star, color: Colors.amber, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '$rating / 5.0',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showTransactionHistorySheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Total Tips',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            SizedBox(width: 4),
                            Icon(LucideIcons.chevronRight, color: Colors.white38, size: 12),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatRupiah(totalTips),
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: Colors.white12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: InkWell(
                  onTap: _showTransactionHistorySheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.wallet, color: Color(0xFF38BDF8), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Saldo LaundryPay',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            SizedBox(width: 4),
                            Icon(LucideIcons.chevronRight, color: Colors.white38, size: 12),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatRupiah(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pengantaran Sukses', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('$completed Pesanan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tugas Berjalan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${_activeTasks.length} Pesanan', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showWithdrawalSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withAlpha(40),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.arrowUpRight, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Tarik Saldo (WD)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _showTransactionHistorySheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.receiptText, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Riwayat Mutasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<OrderModel> tasks, {required bool isActive}) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.truck, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                isActive ? 'Tidak Ada Tugas Berjalan' : 'Belum Ada Riwayat Selesai',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                isActive
                    ? 'Semua tugas penjemputan dan pengantaran cucian telah rampung!'
                    : 'Pesanan yang selesai diantar akan tampil di sini lengkap dengan tips dan rating.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final custName = task.customerName;
        final custPhone = task.customerPhone;
        final address = task.pickupAddress.isNotEmpty ? task.pickupAddress : task.deliveryAddress;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(order: task),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Invoice & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        task.invoiceNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: task.isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.statusName.isNotEmpty ? task.statusName : task.status.toApiString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: task.isCompleted ? const Color(0xFF166534) : const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Service Name & Qty
                  Text(
                    '${task.serviceName} (${task.quantity} ${task.unit})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),

                  // Customer info
                  if (custName != null && custName.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(LucideIcons.user, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          custName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Address with Map link
                  if (address.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Tips & Rating if present
                  if (task.tipAmount != null && task.tipAmount! > 0) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.coins, color: Color(0xFF16A34A), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Tips Diterima Kurir:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.formatRupiah(task.tipAmount!),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (task.rating != null) ...[
                    Row(
                      children: [
                        const Icon(LucideIcons.star, color: Colors.amber, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${task.rating}.0 Bintang dari Pelanggan',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                    if (task.review != null && task.review!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"${task.review!.trim()}"',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      ),
                    ],
                  ],

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Action buttons: WhatsApp, Phone, Navigation, Update Status
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (custPhone != null && custPhone.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            final msg = 'Halo kak ${custName ?? ''}, saya kurir Almas Laundry terkait pesanan #${task.invoiceNo}.';
                            LauncherHelper.openWhatsApp(phone: custPhone, message: msg);
                          },
                          icon: const Icon(LucideIcons.messageCircle, size: 13, color: Color(0xFF16A34A)),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.green.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            LauncherHelper.openPhoneCall(custPhone);
                          },
                          icon: const Icon(LucideIcons.phone, size: 13, color: AppColors.primary),
                          label: const Text('Telepon', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                      if (address.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            LauncherHelper.openGoogleMaps(address);
                          },
                          icon: const Icon(LucideIcons.navigation, size: 13, color: Color(0xFF6366F1)),
                          label: const Text('Buka Peta', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC7D2FE)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderDetailPage(order: task)),
                          );
                        },
                        icon: const Icon(LucideIcons.fileText, size: 13, color: AppColors.primary),
                        label: const Text('Detail Pesanan', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                      if (isActive)
                        ElevatedButton.icon(
                          onPressed: () => _showStatusDialog(task),
                          icon: const Icon(LucideIcons.edit3, size: 13),
                          label: const Text('Update Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
