import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/service_model.dart';
import '../../../../data/repositories/service_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../widgets/order_checkout_sheet.dart';
import '../widgets/service_card.dart';

class ServicesPage extends StatefulWidget {
  final IServiceRepository? serviceRepository;
  final IUserRepository? userRepository;

  const ServicesPage({
    super.key,
    this.serviceRepository,
    this.userRepository,
  });

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final IServiceRepository _serviceRepository;
  late final IUserRepository _userRepository;

  String _selectedCategoryId = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _services = [];
  List<ServiceCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _serviceRepository = widget.serviceRepository ?? ServiceRepository();
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
      ]);

      if (mounted) {
        setState(() {
          _services = results[0] as List<ServiceModel>;
          _categories = results[1] as List<ServiceCategoryModel>;
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
    final user = await _userRepository.getProfile();
    if (!context.mounted) return;

    OrderCheckoutSheet.show(
      context,
      service: service,
      user: user,
      onOrderSuccess: () {
        _loadServices();
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
