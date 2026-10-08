import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/security_questions.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_realtime_service.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../core/utils/launcher_helper.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/promo_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/wallet_transaction_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../data/repositories/promo_repository.dart';
import '../../../../data/repositories/service_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../courier/presentation/pages/courier_tasks_page.dart';
import '../widgets/top_up_sheet.dart';

class ProfilePage extends StatefulWidget {
  final IUserRepository? userRepository;
  final IAuthRepository? authRepository;
  final IPromoRepository? promoRepository;
  final IServiceRepository? serviceRepository;
  final IPaymentRepository? paymentRepository;

  const ProfilePage({
    super.key,
    this.userRepository,
    this.authRepository,
    this.promoRepository,
    this.serviceRepository,
    this.paymentRepository,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final IUserRepository _userRepository = widget.userRepository ?? UserRepository();
  late final IAuthRepository _authRepository = widget.authRepository ?? AuthRepository();
  late final IServiceRepository _serviceRepository = widget.serviceRepository ?? ServiceRepository();
  late final IPromoRepository _promoRepository = widget.promoRepository ?? PromoRepository();
  UserModel _user = UserModel.empty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userRepository.getProfile();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        NotificationRealtimeService.instance.triggerRefreshRequired();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _user.name);
    final phoneCtrl = TextEditingController(text: _user.phone);
    bool isSaving = false;
    String? err;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Data Profil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Perbarui nama lengkap dan nomor kontak Anda',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (err != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                err!,
                                style: const TextStyle(color: AppColors.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Nama Anda',
                        prefixIcon: Icon(LucideIcons.user, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Nomor HP / WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '081234567890',
                        prefixIcon: Icon(LucideIcons.phone, size: 18),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Simpan Perubahan',
                      icon: LucideIcons.save,
                      isLoading: isSaving,
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();
                              if (name.isEmpty) {
                                setSheetState(() => err = 'Nama lengkap tidak boleh kosong');
                                return;
                              }
                              setSheetState(() {
                                isSaving = true;
                                err = null;
                              });
                              try {
                                final updated = _user.copyWith(
                                  name: name,
                                  phone: phone,
                                );
                                await _userRepository.updateProfile(updated);
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                await _loadProfile();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: AppColors.success,
                                      content: Text('Profil berhasil diperbarui!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isSaving = false;
                                  err = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    final hasSQ = _user.hasSecurityQuestions;
    String q1 = _user.question1 ?? SecurityQuestions.list[0];
    String q2 = _user.question2 ?? SecurityQuestions.list[1];
    final a1Ctrl = TextEditingController();
    final a2Ctrl = TextEditingController();

    bool isSaving = false;
    String? err;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SafeArea(
            child: Padding(
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasSQ ? 'Ganti Kata Sandi' : 'Ganti Kata Sandi & Pertanyaan Keamanan',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasSQ
                                    ? 'Perbarui kata sandi akun Anda secara berkala untuk menjaga keamanan'
                                    : 'Perbarui kata sandi dan amankan akun dengan 2 pertanyaan keamanan',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                  if (hasSQ) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF059669)),
                              SizedBox(width: 8),
                              Text(
                                '2 Pertanyaan Keamanan Telah Aktif',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pertanyaan keamanan berikut akan digunakan otomatis untuk memverifikasi akun Anda jika sewaktu-waktu lupa kata sandi:',
                            style: TextStyle(fontSize: 11, color: Color(0xFF047857), height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          if (_user.question1 != null && _user.question1!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('1. ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                  Expanded(
                                    child: Text(
                                      _user.question1!,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_user.question2 != null && _user.question2!.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('2. ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                Expanded(
                                  child: Text(
                                    _user.question2!,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.helpCircle, size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Pengaturan Pertanyaan Keamanan (Wajib Pertama Kali)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Khusus akun pelanggan: Karena akun baru menggunakan kata sandi bawaan, Anda wajib mengatur 2 Pertanyaan Keamanan saat pertama kali mengganti kata sandi. Pertanyaan ini akan digunakan untuk memulihkan akun saat Anda lupa kata sandi di masa mendatang.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (err != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(err!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const Text('Kata Sandi Saat Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••', prefixIcon: Icon(LucideIcons.lock, size: 18)),
                  ),
                  const SizedBox(height: 12),

                  const Text('Kata Sandi Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Minimal 6 karakter', prefixIcon: Icon(LucideIcons.key, size: 18)),
                  ),
                  const SizedBox(height: 12),

                  const Text('Konfirmasi Kata Sandi Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Ulangi kata sandi baru', prefixIcon: Icon(LucideIcons.key, size: 18)),
                  ),

                  if (!hasSQ) ...[
                    const Divider(height: 24),
                    const Text('Pertanyaan Keamanan 1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: q1,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: SecurityQuestions.list.map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => q1 = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: a1Ctrl,
                      decoration: const InputDecoration(hintText: 'Jawaban pertanyaan 1', prefixIcon: Icon(LucideIcons.shieldQuestion, size: 18)),
                    ),
                    const SizedBox(height: 14),

                    const Text('Pertanyaan Keamanan 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: q2,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: SecurityQuestions.list.map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => q2 = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: a2Ctrl,
                      decoration: const InputDecoration(hintText: 'Jawaban pertanyaan 2', prefixIcon: Icon(LucideIcons.shieldQuestion, size: 18)),
                    ),
                  ],

                  const SizedBox(height: 20),

                  CustomButton(
                    text: 'Simpan Perubahan',
                    icon: LucideIcons.save,
                    isLoading: isSaving,
                    onPressed: () async {
                      if (oldPassCtrl.text.isEmpty || newPassCtrl.text.isEmpty) {
                        setSheetState(() => err = 'Kata sandi saat ini dan baru wajib diisi');
                        return;
                      }
                      if (newPassCtrl.text != confirmPassCtrl.text) {
                        setSheetState(() => err = 'Konfirmasi kata sandi tidak sesuai');
                        return;
                      }
                      if (newPassCtrl.text.length < 6) {
                        setSheetState(() => err = 'Kata sandi baru minimal 6 karakter');
                        return;
                      }

                      if (!hasSQ) {
                        if (a1Ctrl.text.trim().isEmpty || a2Ctrl.text.trim().isEmpty) {
                          setSheetState(() => err = 'Kedua jawaban pertanyaan keamanan wajib diisi');
                          return;
                        }
                      }

                      setSheetState(() {
                        isSaving = true;
                        err = null;
                      });

                      try {
                        await _authRepository.changePassword(
                          oldPassword: oldPassCtrl.text,
                          newPassword: newPassCtrl.text,
                          question1: hasSQ ? null : q1,
                          answer1: hasSQ ? null : a1Ctrl.text.trim(),
                          question2: hasSQ ? null : q2,
                          answer2: hasSQ ? null : a2Ctrl.text.trim(),
                        );

                        await _loadProfile();

                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: AppColors.success, content: Text('Kata sandi berhasil diperbarui!')),
                          );
                        }
                      } catch (e) {
                        setSheetState(() {
                          isSaving = false;
                          err = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  void _showAddressFormDialog({AddressModel? existingAddress}) {
    final isEdit = existingAddress != null;
    final labelCtrl = TextEditingController(text: existingAddress?.label ?? '');
    final addrCtrl = TextEditingController(text: existingAddress?.fullAddress ?? '');
    bool isDetectingLocation = false;
    bool isSaving = false;
    String? err;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Alamat Penjemputan' : 'Tambah Alamat Penjemputan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEdit ? 'Perbarui detail alamat penjemputan Anda' : 'Simpan alamat baru untuk pesanan laundry',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (err != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(err!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text('Label Alamat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Rumah, Kantor, Kos',
                      prefixIcon: Icon(LucideIcons.tag, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Alamat Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: isDetectingLocation
                            ? null
                            : () async {
                                setSheetState(() => isDetectingLocation = true);
                                final result = await LocationService.getCurrentLocationWithAddress(sheetCtx);
                                setSheetState(() {
                                  isDetectingLocation = false;
                                  if (result != null) {
                                    addrCtrl.text = result.fullAddress;
                                    if (labelCtrl.text.isEmpty) {
                                      labelCtrl.text = result.suggestedLabel;
                                    }
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
                                isDetectingLocation ? 'Mencari GPS...' : 'Gunakan Lokasi GPS',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addrCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Jl. Nama Jalan No. XX, Kelurahan, Kecamatan, Kota',
                      prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: isEdit ? 'Simpan Perubahan' : 'Tambah Alamat',
                    icon: isEdit ? LucideIcons.save : LucideIcons.plus,
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final label = labelCtrl.text.trim();
                            final addr = addrCtrl.text.trim();
                            if (label.isEmpty || addr.isEmpty) {
                              setSheetState(() => err = 'Label dan alamat lengkap wajib diisi');
                              return;
                            }

                            setSheetState(() {
                              isSaving = true;
                              err = null;
                            });

                            try {
                              if (isEdit) {
                                await _userRepository.updateAddress(
                                  id: existingAddress.id,
                                  label: label,
                                  fullAddress: addr,
                                  isDefault: existingAddress.isDefault,
                                );
                              } else {
                                await _userRepository.addAddress(
                                  label: label,
                                  fullAddress: addr,
                                  isDefault: _user.addresses.isEmpty,
                                );
                              }
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              await _loadProfile();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.success,
                                    content: Text(isEdit ? 'Alamat berhasil diperbarui!' : 'Alamat berhasil ditambahkan!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() {
                                isSaving = false;
                                err = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAddress(AddressModel address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('Hapus Alamat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus alamat "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _userRepository.deleteAddress(address.id);
                await _loadProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('Alamat berhasil dihapus'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showManageAddressesModal() {
    if (_user.addresses.isEmpty) {
      _showAddressFormDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alamat Penjemputan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_user.addresses.length} Alamat tersimpan',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetCtx),
                          icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _user.addresses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final addr = _user.addresses[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(bottomSheetCtx);
                              _showAddressFormDialog(existingAddress: addr);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: addr.isDefault ? AppColors.primary : AppColors.border,
                                  width: addr.isDefault ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              addr.label,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            if (addr.isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Utama',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          addr.fullAddress,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.primary),
                                        tooltip: 'Ubah Alamat',
                                        onPressed: () {
                                          Navigator.pop(bottomSheetCtx);
                                          _showAddressFormDialog(existingAddress: addr);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                                        tooltip: 'Hapus Alamat',
                                        onPressed: () {
                                          Navigator.pop(bottomSheetCtx);
                                          _confirmDeleteAddress(addr);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Tambah Alamat Baru'),
                        onPressed: () {
                          Navigator.pop(bottomSheetCtx);
                          _showAddressFormDialog();
                        },
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

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Almas Laundry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authRepository.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar Akun'),
          ),
        ],
      ),
    );
  }

  void _showRewardsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.star, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Poin Rewards Saya',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Kumpulkan poin dari setiap pesanan laundry Anda',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Point Balance Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(LucideIcons.award, size: 18, color: Color(0xFFD97706)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Total Poin Anda',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: Text(
                                    _user.memberTier,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_user.rewardPoints} Poin',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(180),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Setiap transaksi Rp 1.000 otomatis mendapatkan 1 Poin Reward saat cucian selesai!',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Redeem Section
                      const Text(
                        'Tukarkan Poin dengan Voucher Diskon',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<List<PromoModel>>(
                        future: _promoRepository.getPromos(category: 'Reward Point', activeOnly: true),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            );
                          }

                          final rewardPromos = (snapshot.data ?? [])
                              .where((p) => (p.pointsRequired > 0 || p.pointsSpent > 0) && p.isValidPeriod)
                              .toList();

                          if (rewardPromos.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(LucideIcons.ticket, size: 28, color: AppColors.textMuted),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum Ada Voucher Poin Reward',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Nantikan voucher reward menarik dari Almas Laundry segera!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: rewardPromos.map((promo) {
                              final pointsReq = promo.pointsRequired > 0 ? promo.pointsRequired : promo.pointsSpent;
                              final hasEnough = _user.rewardPoints >= pointsReq;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: hasEnough ? const Color(0xFFFEF3C7) : AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        promo.icon,
                                        color: hasEnough ? const Color(0xFFD97706) : AppColors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            promo.title,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${promo.discountLabel} • Min. ${promo.minOrderAmount > 0 ? CurrencyFormatter.formatRupiah(promo.minOrderAmount) : "Tanpa Min."}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          if (promo.formattedPeriod.isNotEmpty)
                                            Text(
                                              'Berlaku: ${promo.formattedPeriod}',
                                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (!hasEnough) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Poin Anda belum cukup (${_user.rewardPoints}/$pointsReq Poin). Pesan laundry lagi untuk kumpulkan poin!'),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                          return;
                                        }

                                        try {
                                          await _userRepository.redeemPoints(
                                            points: pointsReq,
                                            code: promo.code,
                                            title: promo.title,
                                            subtitle: promo.subtitle,
                                            category: promo.category,
                                            benefitType: promo.benefitType,
                                            discountType: promo.discountType,
                                            discountAmount: promo.discountAmount,
                                            maxDiscount: promo.maxDiscount,
                                            minOrderAmount: promo.minOrderAmount,
                                            promosId: promo.id,
                                            startDate: promo.startDate,
                                            endDate: promo.endDate,
                                          );
                                          await _loadProfile();
                                          setSheetState(() {});
                                          Clipboard.setData(ClipboardData(text: promo.code));
                                          if (mounted && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Selamat! Berhasil menukarkan $pointsReq poin. Voucher "${promo.code}" tersimpan di akun Anda & kode telah disalin!'),
                                                backgroundColor: const Color(0xFF059669),
                                                duration: const Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Gagal menukarkan poin: $e'), backgroundColor: AppColors.error),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasEnough ? AppColors.primary : AppColors.border,
                                        foregroundColor: hasEnough ? Colors.white : AppColors.textMuted,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        hasEnough ? 'Tukar ($pointsReq)' : '$pointsReq Poin',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Points History Section
                      const Text(
                        'Riwayat Poin Reward',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<List<PointHistoryModel>>(
                        future: _userRepository.getPointHistories(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            );
                          }

                          final histories = snapshot.data ?? [];
                          if (histories.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(LucideIcons.history, size: 28, color: AppColors.textMuted),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum ada riwayat perolehan poin',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Poin otomatis masuk setiap kali pesanan cucian Anda selesai!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: histories.map((h) {
                              final isEarn = h.isEarn;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isEarn ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isEarn ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                                        color: isEarn ? const Color(0xFF059669) : AppColors.error,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            h.title,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          if (h.description.isNotEmpty)
                                            Text(
                                              h.description,
                                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      isEarn ? '+${h.points}' : '-${h.points}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isEarn ? const Color(0xFF059669) : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWalletTransactionHistorySheet(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
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
                        'Riwayat Mutasi Saldo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(14),
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
                  const Text('Saldo LaundryPay Anda:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    CurrencyFormatter.formatRupiah(_user.laundryPayBalance),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WalletTransactionModel>>(
                future: _userRepository.getWalletTransactions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)));
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.receipt, size: 36, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada riwayat transaksi saldo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Mutasi pengisian saldo, tips, dan pembayaran pesanan akan tampil di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const Divider(height: 12, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final isCredit = item.isCredit;
                      final isTip = item.category.toLowerCase() == 'tip';
                      final isTopup = item.category.toLowerCase() == 'topup';

                      Color iconColor = isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                      Color iconBg = isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
                      IconData iconData = isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;

                      if (isTip) {
                        iconColor = const Color(0xFF16A34A);
                        iconBg = const Color(0xFFDCFCE7);
                        iconData = LucideIcons.coins;
                      } else if (isTopup) {
                        iconColor = const Color(0xFF0284C7);
                        iconBg = const Color(0xFFE0F2FE);
                        iconData = LucideIcons.wallet;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                              child: Icon(iconData, color: iconColor, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  if (item.description != null && item.description!.isNotEmpty)
                                    Text(
                                      item.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? '+' : '-'}${CurrencyFormatter.formatRupiah(item.amount)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVouchersModal() {
    final searchCtrl = TextEditingController();
    String? promoNotice;
    bool isValidPromo = false;
    bool isCheckingPromo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.ticket, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voucher & Promo Saya',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Daftar voucher diskon yang sudah Anda miliki dan siap pakai',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Promo Code Input Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Punya Kode Promo Khusus?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: searchCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Masukkan kode voucher',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isCheckingPromo ? null : () async {
                                    final code = searchCtrl.text.trim().toUpperCase();
                                    if (code.isEmpty) return;
                                    setSheetState(() => isCheckingPromo = true);
                                    try {
                                      final v = await _userRepository.verifyVoucher(code);
                                      setSheetState(() {
                                        promoNotice = 'Selamat! Voucher "${v.title}" (${v.code}) aktif & siap digunakan!';
                                        isValidPromo = true;
                                        isCheckingPromo = false;
                                      });
                                    } catch (e) {
                                      setSheetState(() {
                                        promoNotice = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
                                        isValidPromo = false;
                                        isCheckingPromo = false;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: isCheckingPromo
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Cek Kode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            if (promoNotice != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isValidPromo ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                                    size: 15,
                                    color: isValidPromo ? const Color(0xFF059669) : AppColors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      promoNotice!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isValidPromo ? const Color(0xFF065F46) : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Voucher Tersimpan di Akun Saya',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<List<PromoModel>>(
                        future: _userRepository.getUserVouchers(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            );
                          }

                          final vouchers = snapshot.data ?? [];
                          if (vouchers.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Icon(LucideIcons.ticket, size: 44, color: AppColors.textMuted),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Belum Ada Voucher Ditukarkan',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tukarkan Poin Rewards Anda sekarang untuk mendapatkan voucher diskon pesanan cucian!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(sheetCtx);
                                      _showRewardsModal();
                                    },
                                    icon: const Icon(LucideIcons.award, size: 16),
                                    label: const Text('Tukarkan Poin Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: vouchers.map((promo) {
                              final isUsed = promo.isUsed;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isUsed ? const Color(0xFFF9FAFB) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isUsed ? const Color(0xFFE5E7EB) : AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isUsed ? const Color(0xFFF3F4F6) : AppColors.primary.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            promo.icon,
                                            color: isUsed ? AppColors.textMuted : AppColors.primary,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                promo.title,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: isUsed ? AppColors.textSecondary : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                promo.subtitle.isNotEmpty ? promo.subtitle : 'Min. transaksi ${CurrencyFormatter.formatRupiah(promo.minOrderAmount)}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isUsed
                                                ? const Color(0xFFF3F4F6)
                                                : promo.isExpired
                                                    ? const Color(0xFFFEF2F2)
                                                    : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isUsed
                                                  ? const Color(0xFFE5E7EB)
                                                  : promo.isExpired
                                                      ? const Color(0xFFFECACA)
                                                      : const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: Text(
                                            isUsed
                                                ? 'Sudah Digunakan'
                                                : promo.isExpired
                                                    ? 'Kedaluwarsa'
                                                    : promo.discountLabel,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isUsed
                                                  ? AppColors.textMuted
                                                  : promo.isExpired
                                                      ? AppColors.error
                                                      : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text('KODE: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                              Text(
                                                promo.code,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                  color: isUsed ? AppColors.textMuted : AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isUsed)
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: promo.code));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Kode voucher "${promo.code}" berhasil disalin!'),
                                                  backgroundColor: AppColors.primary,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(LucideIcons.copy, size: 14, color: Colors.white),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Salin Kode',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'Terpakai',
                                            style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTopUpDialog() {
    TopUpSheet.show(
      context,
      user: _user,
      onTopUpSuccess: _loadProfile,
    );
  }

  void _showPaymentMethodsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.creditCard, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metode Pembayaran',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pilihan saluran pembayaran resmi Almas Laundry',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Section 1: LaundryPay Balance Card (Utama)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFF0F9FF),
                            AppColors.primaryLight.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(LucideIcons.wallet, color: AppColors.primary, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'LaundryPay (Dompet Digital)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Text(
                                  'Aktif • Bebas Biaya',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Saldo Anda Saat Ini:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatRupiah(_user.laundryPayBalance),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  _showTopUpDialog();
                                },
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('Isi Saldo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _showWalletTransactionHistorySheet(context);
                                },
                                icon: const Icon(LucideIcons.history, size: 14),
                                label: const Text('Riwayat Mutasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: QRIS Otomatis
                    const Text('Pembayaran Digital Instan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    _buildPaymentChannelItem(
                      icon: LucideIcons.qrCode,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                      title: 'QRIS Instant (Semua Bank & E-Wallet)',
                      subtitle: 'BCA, Mandiri, BRI, BNI, GoPay, OVO, DANA, ShopeePay. Terbit otomatis saat checkout faktur.',
                      badgeText: 'Otomatis',
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Transfer Rekening Bank
                    const Text('Transfer Rekening Bank Resmi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    FutureBuilder<List<PaymentMethodModel>>(
                      future: _serviceRepository.getPaymentMethods(),
                      builder: (context, snapshot) {
                        final allMethods = snapshot.data ?? [];
                        
                        // Filter real bank transfers (exclude cash, qris, laundrypay, ewallet)
                        final bankMethods = allMethods.where((m) {
                          final name = m.name.toLowerCase();
                          final code = m.code.toLowerCase();
                          final type = (m.type ?? '').toLowerCase();
                          final isCash = type == 'cash' || code.contains('cash') || name.contains('tunai') || name.contains('cod');
                          final isQris = type == 'qris' || code.contains('qris') || name.contains('qris');
                          final isWallet = type == 'ewallet' || code.contains('wallet') || name.contains('gopay') || name.contains('dana') || name.contains('ovo');
                          final isLPay = type == 'laundrypay' || code.contains('laundrypay') || name.contains('laundrypay');
                          return m.isActive && !isCash && !isQris && !isWallet && !isLPay;
                        }).toList();

                        if (bankMethods.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          children: bankMethods.map((pm) {
                            final accNum = pm.accountNumber ?? '-';
                            final accName = pm.accountName != null && pm.accountName!.isNotEmpty
                                ? 'a.n. ${pm.accountName}'
                                : '';
                            return _buildPaymentChannelItem(
                              icon: LucideIcons.building2,
                              iconColor: AppColors.primary,
                              iconBg: AppColors.primaryLight.withValues(alpha: 0.3),
                              title: pm.name,
                              subtitle: accName.isNotEmpty ? '$accNum • $accName' : accNum,
                              copyValue: accNum != '-' ? accNum : pm.name,
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Section 4: Transfer E-Wallet
                    FutureBuilder<List<PaymentMethodModel>>(
                      future: _serviceRepository.getPaymentMethods(),
                      builder: (context, snapshot) {
                        final allMethods = snapshot.data ?? [];
                        final ewalletMethods = allMethods.where((m) {
                          final name = m.name.toLowerCase();
                          final code = m.code.toLowerCase();
                          final type = (m.type ?? '').toLowerCase();
                          final isWallet = type == 'ewallet' || code.contains('wallet') || name.contains('gopay') || name.contains('dana') || name.contains('ovo') || name.contains('shopeepay');
                          return m.isActive && isWallet;
                        }).toList();

                        if (ewalletMethods.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Transfer E-Wallet Resmi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            ...ewalletMethods.map((pm) {
                              final phone = pm.accountNumber ?? '-';
                              final name = pm.accountName != null && pm.accountName!.isNotEmpty
                                  ? 'a.n. ${pm.accountName}'
                                  : '';
                              return _buildPaymentChannelItem(
                                icon: LucideIcons.smartphone,
                                iconColor: const Color(0xFF0284C7),
                                iconBg: const Color(0xFFE0F2FE),
                                title: pm.name,
                                subtitle: name.isNotEmpty ? '$phone • $name' : phone,
                                copyValue: phone != '-' ? phone : pm.name,
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Section 5: Tunai / COD
                    const Text('Pembayaran Tunai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    _buildPaymentChannelItem(
                      icon: LucideIcons.banknote,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                      title: 'Tunai / Cash on Delivery (COD)',
                      subtitle: 'Bayar tunai langsung kepada kurir saat antar-jemput atau di kasir outlet.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpCenterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.helpCircle, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pusat Bantuan & CS',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Layanan pelanggan & solusi kendala pesanan Anda',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // WhatsApp Support Card
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
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.phone, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Customer Service WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                    Text('Respon Cepat • 07.00 - 21.00 WIB', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '+62 812-1519-9230',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: '+6281215199230'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nomor WhatsApp +62 812-1519-9230 berhasil disalin!'),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                },
                                icon: const Icon(LucideIcons.copy, size: 14),
                                label: const Text('Salin Nomor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () async {
                                  final ok = await LauncherHelper.openWhatsApp(
                                    phone: '+6281215199230',
                                    message: 'Halo Customer Service Almas Laundry, saya ingin menanyakan bantuan terkait layanan laundry. Mohon informasinya.',
                                  );
                                  if (!ok && mounted) {
                                    Clipboard.setData(const ClipboardData(text: '+6281215199230'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Nomor WhatsApp +62 812-1519-9230 telah disalin ke clipboard.'),
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF065F46),
                                  side: const BorderSide(color: Color(0xFF059669)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Buka Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email Support & Jam Operasional
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.mail, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email Dukungan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('support@almaslaundry.com', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(const ClipboardData(text: 'support@almaslaundry.com'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Email support@almaslaundry.com berhasil disalin!')),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(LucideIcons.copy, size: 14, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          const Row(
                            children: [
                              Icon(LucideIcons.clock, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Jam Operasional Layanan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('Senin - Minggu: 07.00 - 21.00 WIB', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // FAQ Section
                    const Text('Pertanyaan yang Sering Diajukan (FAQ)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    _buildFaqItem(
                      'Berapa lama estimasi proses pengerjaan cucian?',
                      'Layanan Reguler selesai dalam 24 jam (1 hari kerja). Layanan Express/Kilat selesai dalam 3-6 jam setelah pakaian tiba di workshop kami.',
                    ),
                    _buildFaqItem(
                      'Apakah ada gratis biaya jemput & antar pakaian?',
                      'Ya! Layanan penjemputan dan pengantaran gratis untuk seluruh area layanan aktif Almas Laundry (Kartasura, Solo Barat, dan sekitarnya) atau dengan voucher GRATISONGKIR.',
                    ),
                    _buildFaqItem(
                      'Bagaimana jika pakaian luntur, rusak, atau tertukar?',
                      'Almas Laundry menerapkan SOP sortir warna ketat dan 1 mesin untuk 1 pelanggan sehingga tidak tertukar. Jika ada kelalaian, kami menjamin garansi cuci ulang atau kompensasi ganti rugi 100%.',
                    ),
                    _buildFaqItem(
                      'Bagaimana cara memantau status cucian?',
                      'Anda dapat mengecek progres cucian secara real-time pada tab menu "Pesanan" di aplikasi, mulai dari status Dijemput, Dicuci, Pengeringan, Disetrika, hingga Siap Diantar.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.info, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tentang Almas Laundry',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Informasi aplikasi, profil usaha, dan workshop kami',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Brand Card
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(LucideIcons.waves, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Almas Laundry',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withAlpha(40)),
                            ),
                            child: const Text(
                              'Versi v1.0.0 (Biru Air Solid Edition)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Almas Laundry adalah penyedia jasa binatu dan perawatan pakaian profesional yang mengedepankan kualitas pencucian bersih maksimal, aroma wangi tahan lama, serta kemudahan pemesanan antar-jemput digital.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4 Pillars of Excellence
                    const Text('Komitmen Layanan Terbaik Kami', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildAboutPillar(LucideIcons.shieldCheck, '1 Mesin 1 Pelanggan', 'Cucian tidak dicampur')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildAboutPillar(LucideIcons.sparkles, 'Deterjen Premium', 'Aman serat & warna')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildAboutPillar(LucideIcons.clock, 'Tepat Waktu', 'Reguler & Kilat Express')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildAboutPillar(LucideIcons.checkCircle2, 'Garansi 100%', 'Kepuasan cuci bersih')),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Workshop & Contact details
                    const Text('Outlet & Workshop Resmi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildAboutRow(
                            LucideIcons.mapPin,
                            'Alamat Workshop',
                            'Jl. Boyolali - Solo No. 45, Kartasura, Jawa Tengah 57169',
                            onCopy: () {
                              Clipboard.setData(const ClipboardData(text: 'Jl. Boyolali - Solo No. 45, Kartasura, Jawa Tengah 57169'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Alamat workshop berhasil disalin!')),
                              );
                            },
                          ),
                          const Divider(height: 20),
                          _buildAboutRow(LucideIcons.clock, 'Jam Buka Outlet', '07.00 - 21.00 WIB (Buka Setiap Hari)'),
                          const Divider(height: 20),
                          _buildAboutRow(
                            LucideIcons.phone,
                            'Kontak WhatsApp',
                            '+62 812-1519-9230',
                            onCopy: () {
                              Clipboard.setData(const ClipboardData(text: '+6281215199230'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nomor kontak berhasil disalin!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Copyright footer
                    const Center(
                      child: Text(
                        '© 2026 Almas Laundry Indonesia.\nHak Cipta Dilindungi Undang-Undang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentChannelItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? copyValue,
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(badgeText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          if (copyValue != null && copyValue.isNotEmpty) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title ($copyValue) berhasil disalin!'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.copy, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Salin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          question,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutPillar(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String title, String subtitle, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.copy, size: 14, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Akun Saya'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Card (Solid Flat)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _user.name.trim().isNotEmpty
                                      ? _user.name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
                                      : 'P',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
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
                                          _user.name.trim().isNotEmpty ? _user.name : 'Pelanggan',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _user.memberTier,
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_user.phone} • ${_user.email}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_user.userCode != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kode ID: ${_user.userCode}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _showEditProfileDialog,
                              icon: const Icon(LucideIcons.edit2, size: 18, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        if (_user.hasPermission('mobile.laundry-pay')) ...[
                          const Divider(height: 24),

                          // Wallet & Points summary
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletItem(
                                  'Saldo LaundryPay',
                                  CurrencyFormatter.formatRupiah(_user.laundryPayBalance),
                                  LucideIcons.wallet,
                                  AppColors.primary,
                                  onTap: _showPaymentMethodsModal,
                                ),
                              ),
                              Container(width: 1, height: 36, color: AppColors.border),
                              Expanded(
                                child: _buildWalletItem(
                                  'Poin Rewards',
                                  '${_user.rewardPoints} Poin',
                                  LucideIcons.star,
                                  const Color(0xFFD97706),
                                  onTap: _showRewardsModal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Settings & Menus
                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: LucideIcons.mapPin,
                          title: 'Alamat Penjemputan',
                          subtitle: '${_user.addresses.length} Alamat tersimpan',
                          onTap: _showManageAddressesModal,
                        ),
                        const Divider(),
                        _buildMenuItem(
                          icon: LucideIcons.shieldCheck,
                          title: 'Keamanan & Kata Sandi',
                          subtitle: _user.hasSecurityQuestions
                              ? 'Perbarui kata sandi akun'
                              : 'Ganti password & 2 pertanyaan keamanan',
                          onTap: _showChangePasswordDialog,
                        ),
                        if (_user.hasPermission('mobile.promo')) ...[
                          const Divider(),
                          _buildMenuItem(
                            icon: LucideIcons.ticket,
                            title: 'Voucher & Promo Saya',
                            subtitle: 'Diskon dan kupon siap pakai',
                            onTap: _showVouchersModal,
                          ),
                        ],
                        if (_user.hasPermission('mobile.laundry-pay')) ...[
                          const Divider(),
                          _buildMenuItem(
                            icon: LucideIcons.creditCard,
                            title: 'Metode Pembayaran',
                            subtitle: 'LaundryPay, QRIS, Transfer, Tunai',
                            onTap: _showPaymentMethodsModal,
                          ),
                        ],
                        if (_user.hasPermission('mobile.tugas-kurir')) ...[
                          const Divider(),
                          _buildMenuItem(
                            icon: LucideIcons.truck,
                            title: 'Menu Kurir & Tips',
                            subtitle: 'Tugas penjemputan, pengantaran, dan akumulasi tips',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CourierTasksPage()),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: LucideIcons.helpCircle,
                          title: 'Pusat Bantuan & CS',
                          subtitle: 'Hubungi layanan pelanggan Almas Laundry',
                          onTap: _showHelpCenterModal,
                        ),
                        const Divider(),
                        _buildMenuItem(
                          icon: LucideIcons.info,
                          title: 'Tentang Almas Laundry',
                          subtitle: 'Versi v1.0.0 (Biru Air Solid Edition)',
                          onTap: _showAboutDialog,
                        ),
                        const Divider(),
                        _buildMenuItem(
                          icon: LucideIcons.logOut,
                          title: 'Keluar Akun',
                          titleColor: AppColors.error,
                          iconColor: AppColors.error,
                          onTap: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWalletItem(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: effectiveIconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
      trailing: const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
