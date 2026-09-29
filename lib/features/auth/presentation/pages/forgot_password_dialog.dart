import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../data/repositories/auth_repository.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final IAuthRepository? authRepository;

  const ForgotPasswordDialog({super.key, this.authRepository});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final IAuthRepository _authRepository;
  int _currentStep = 1; // Step 1: Identifier, Step 2: Answer 2 questions, Step 3: New Password

  final _identifierController = TextEditingController();
  final _answer1Controller = TextEditingController();
  final _answer2Controller = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Data from backend
  String _sessionToken = '';
  String _resetToken = '';
  String _userName = '';
  String _maskedEmail = '';
  String _maskedPhone = '';
  String _question1 = '';
  String _question2 = '';

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? AuthRepository();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _answer1Controller.dispose();
    _answer2Controller.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleStep1() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Email atau nomor HP wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _authRepository.initForgotPassword(identifier);
      setState(() {
        _sessionToken = res['session_token']?.toString() ?? '';
        _userName = res['name']?.toString() ?? '';
        _maskedEmail = res['masked_email']?.toString() ?? '';
        _maskedPhone = res['masked_phone']?.toString() ?? '';
        _question1 = res['question_1']?.toString() ?? '';
        _question2 = res['question_2']?.toString() ?? '';
        _currentStep = 2;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep2() async {
    final a1 = _answer1Controller.text.trim();
    final a2 = _answer2Controller.text.trim();

    if (a1.isEmpty || a2.isEmpty) {
      setState(() => _errorMessage = 'Semua jawaban pertanyaan wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authRepository.verifySecurityQuestions(
        sessionToken: _sessionToken,
        answer1: a1,
        answer2: a2,
      );
      setState(() {
        _resetToken = token;
        _currentStep = 3;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep3() async {
    final p1 = _newPasswordController.text;
    final p2 = _confirmPasswordController.text;

    if (p1.isEmpty || p2.isEmpty) {
      setState(() => _errorMessage = 'Kata sandi baru wajib diisi');
      return;
    }

    if (p1 != p2) {
      setState(() => _errorMessage = 'Konfirmasi kata sandi tidak cocok');
      return;
    }

    if (p1.length < 6) {
      setState(() => _errorMessage = 'Kata sandi minimal 6 karakter');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final msg = await _authRepository.resetPasswordWithToken(
        resetToken: _resetToken,
        newPassword: p1,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(msg),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.keyRound, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pemulihan Kata Sandi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Tahap $_currentStep dari 3',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textMuted),
                ),
              ],
            ),
            const Divider(height: 24),

            // Step Indicator
            Row(
              children: [
                _buildStepBadge(1, 'Identitas', _currentStep >= 1, _currentStep == 1),
                Expanded(child: Container(height: 2, color: _currentStep > 1 ? AppColors.primary : AppColors.border)),
                _buildStepBadge(2, 'Pertanyaan', _currentStep >= 2, _currentStep == 2),
                Expanded(child: Container(height: 2, color: _currentStep > 2 ? AppColors.primary : AppColors.border)),
                _buildStepBadge(3, 'Sandi Baru', _currentStep >= 3, _currentStep == 3),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_currentStep == 1) _buildStep1UI(),
            if (_currentStep == 2) _buildStep2UI(),
            if (_currentStep == 3) _buildStep3UI(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBadge(int step, String label, bool isDone, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone ? AppColors.primary : AppColors.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? AppColors.primary : (isDone ? AppColors.primary : AppColors.border),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isDone ? Colors.white : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1UI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Masukkan Email atau No. HP Anda yang terdaftar sebagai pelanggan:',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _identifierController,
          decoration: const InputDecoration(
            hintText: 'nama@domain.com atau 08123456789',
            prefixIcon: Icon(LucideIcons.userCheck, size: 18),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Lanjutkan',
          icon: LucideIcons.arrowRight,
          isLoading: _isLoading,
          onPressed: _handleStep1,
        ),
      ],
    );
  }

  Widget _buildStep2UI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akun Ditemukan: $_userName',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '$_maskedEmail • $_maskedPhone',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Question 1
        Text(
          '1. $_question1',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _answer1Controller,
          decoration: const InputDecoration(
            hintText: 'Jawaban pertanyaan 1',
            prefixIcon: Icon(LucideIcons.shieldQuestion, size: 18),
          ),
        ),
        const SizedBox(height: 14),

        // Question 2
        Text(
          '2. $_question2',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _answer2Controller,
          decoration: const InputDecoration(
            hintText: 'Jawaban pertanyaan 2',
            prefixIcon: Icon(LucideIcons.shieldQuestion, size: 18),
          ),
        ),
        const SizedBox(height: 24),

        CustomButton(
          text: 'Verifikasi Jawaban',
          icon: LucideIcons.checkCheck,
          isLoading: _isLoading,
          onPressed: _handleStep2,
        ),
      ],
    );
  }

  Widget _buildStep3UI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verifikasi identitas berhasil! Buat kata sandi baru untuk akun Anda:',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        const Text('Kata Sandi Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Minimal 6 karakter',
            prefixIcon: Icon(LucideIcons.lock, size: 18),
          ),
        ),
        const SizedBox(height: 14),

        const Text('Konfirmasi Kata Sandi Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Ulangi kata sandi baru',
            prefixIcon: Icon(LucideIcons.lock, size: 18),
          ),
        ),
        const SizedBox(height: 24),

        CustomButton(
          text: 'Simpan Kata Sandi Baru',
          icon: LucideIcons.save,
          isLoading: _isLoading,
          onPressed: _handleStep3,
        ),
      ],
    );
  }
}
