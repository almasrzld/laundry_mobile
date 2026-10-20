import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../main_navigation/presentation/pages/main_navigation_page.dart';
import 'forgot_password_dialog.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final IAuthRepository? authRepository;
  final String? initialEmail;
  final bool autoPromptBiometric;

  const LoginPage({
    super.key,
    this.authRepository,
    this.initialEmail,
    this.autoPromptBiometric = true,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final IAuthRepository _authRepository;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Biometric State
  bool _isBiometricSupported = false;
  bool _isBiometricAvailableForLogin = false;
  String _biometricName = 'Sidik Jari';
  bool _isFaceId = false;
  UserModel? _rememberedUser;
  bool _hasTriggeredAutoPrompt = false;

  // Progressive Lockout State
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  int _lockoutStage = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? AuthRepository();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _passwordController = TextEditingController();
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final supported = await BiometricService.instance.isBiometricSupported();
      if (!supported) return;

      final enabled = await BiometricService.instance.isBiometricEnabled();
      final remembered = await BiometricService.instance.getStoredUser();
      final bioName = await BiometricService.instance.getBiometricDisplayName();
      final isFace = await BiometricService.instance.isFaceId();

      if (!mounted) return;
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricAvailableForLogin = enabled && remembered != null;
        _rememberedUser = remembered;
        _biometricName = bioName;
        _isFaceId = isFace;
        if (widget.initialEmail == null && remembered != null) {
          _emailController.text = remembered.email;
        }
      });

      // Auto-prompt jika biometrik aktif, ada akun tersimpan, dan autoPromptBiometric diaktifkan
      if (_isBiometricAvailableForLogin && !_hasTriggeredAutoPrompt && widget.autoPromptBiometric) {
        _hasTriggeredAutoPrompt = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _lockoutSeconds == 0 && !_isLoading) {
              _handleBiometricLogin();
            }
          });
        });
      }
    } catch (e) {
      debugPrint('[LoginPage] Gagal memeriksa status biometrik: $e');
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLoading || _lockoutSeconds > 0) return;

    final authenticated = await BiometricService.instance.authenticate(
      reason: 'Pindai $_biometricName untuk masuk sebagai ${_rememberedUser?.name ?? "Pengguna"}',
    );

    if (!authenticated) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authRepository.loginWithBiometrics();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Selamat datang kembali, ${user.name}!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sesi biometrik kedaluwarsa. Silakan masukkan kata sandi.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _checkOfferBiometrics(UserModel user) async {
    try {
      final supported = await BiometricService.instance.isBiometricSupported();
      if (!supported) return;

      final enabled = await BiometricService.instance.isBiometricEnabled();
      if (enabled) return;

      final bioName = await BiometricService.instance.getBiometricDisplayName();
      final isFace = await BiometricService.instance.isFaceId();
      final token = await SessionService.getToken();
      if (token == null || token.isEmpty) return;

      if (!mounted) return;

      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFace ? LucideIcons.scanFace : LucideIcons.fingerprint,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aktifkan $bioName?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            'Masuk ke akun Anda di perangkat ini lebih cepat dan aman menggunakan $bioName tanpa perlu mengetik kata sandi lagi.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nanti Saja', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Aktifkan Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldEnable == true) {
        final verified = await BiometricService.instance.authenticate(
          reason: 'Pindai $bioName Anda untuk mengaktifkan fitur ini',
        );
        if (verified) {
          await BiometricService.instance.saveBiometricSession(token: token, user: user);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text('$bioName berhasil diaktifkan!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LoginPage] Penawaran biometrik error: $e');
    }
  }

  void _startLockoutCountdown(int seconds, int stage) {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSeconds = seconds;
      _lockoutStage = stage;
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds > 1) {
        setState(() {
          _lockoutSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _errorMessage = null;
        });
      }
    });
  }

  void _showPermanentLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.shieldAlert, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Akun Terkunci Permanen',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demi menjaga keamanan data Anda, akun ini telah dinonaktifkan sementara karena melebihi batas toleransi percobaan masuk berturut-turut.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.store, color: AppColors.error, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Silakan kunjungi toko offline Almas Laundry terdekat dengan membawa kartu identitas (KTP) untuk verifikasi dan pemulihan akun oleh Admin.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti & Tutup', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_lockoutSeconds > 0) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email dan kata sandi wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authRepository.login(email, password);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Selamat datang kembali, ${user.name}!'),
        ),
      );

      if (_isBiometricSupported && !_isBiometricAvailableForLogin) {
        await _checkOfferBiometrics(user);
      }
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.isPermanentlyLocked) {
        _showPermanentLockoutDialog();
        setState(() {
          _errorMessage = e.message;
        });
      } else if (e.isTemporarilyLocked || e.statusCode == 429) {
        final sec = e.remainingSeconds ?? 5;
        final stage = e.lockoutStage ?? (_lockoutStage + 1);
        _startLockoutCountdown(sec, stage);
        setState(() {
          _errorMessage = e.message;
        });
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Brand Header (Solid Flat Theme)
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      LucideIcons.waves,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Masuk ke akun pelanggan Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Main Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lockout Countdown Alert
                      if (_lockoutSeconds > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.lock, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Akun Terkunci Sementara',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Coba lagi dalam $_lockoutSeconds detik.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error message
                      if (_errorMessage != null && _lockoutSeconds == 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
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


                      // Email Field
                      const Text(
                        'Email Pelanggan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: _lockoutSeconds == 0 && !_isLoading,
                        decoration: const InputDecoration(
                          hintText: 'Email Pelanggan',
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kata Sandi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => const ForgotPasswordDialog(),
                              );
                            },
                            child: const Text(
                              'Lupa Kata Sandi?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: _lockoutSeconds == 0 && !_isLoading,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button & Biometric Icon Button
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: _lockoutSeconds > 0
                                  ? 'Terkunci ($_lockoutSeconds dtk)'
                                  : 'Masuk Akun',
                              isLoading: _isLoading,
                              onPressed: _lockoutSeconds > 0 ? null : _handleLogin,
                            ),
                          ),
                          if (_isBiometricAvailableForLogin) ...[
                            const SizedBox(width: 10),
                            Tooltip(
                              message: 'Masuk dengan $_biometricName',
                              child: Material(
                                color: Colors.transparent,
                                child: Ink(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary, width: 1.2),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _isLoading || _lockoutSeconds > 0 ? null : _handleBiometricLogin,
                                    child: Center(
                                      child: Icon(
                                        _isFaceId ? LucideIcons.scanFace : LucideIcons.fingerprint,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun? ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        'Daftar Sekarang',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
