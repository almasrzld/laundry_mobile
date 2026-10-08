import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/app_strings.dart';
import 'core/services/location_service.dart';
import 'core/services/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/main_navigation/presentation/pages/main_navigation_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Gracefully fallback to defaults if .env is missing in tests
  }

  SessionManager.init();
  LocationService.initBackgroundTracker();

  runApp(const LaundryApp());
}

class LaundryApp extends StatefulWidget {
  final bool? isLoggedIn;
  final Widget? initialScreen;

  const LaundryApp({super.key, this.isLoggedIn, this.initialScreen});

  @override
  State<LaundryApp> createState() => _LaundryAppState();
}

class _LaundryAppState extends State<LaundryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if session expired while app was in background
      SessionManager.checkInactivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (widget.initialScreen != null) {
      homeScreen = widget.initialScreen!;
    } else if (widget.isLoggedIn != null) {
      homeScreen = widget.isLoggedIn! ? const MainNavigationPage() : const LoginPage();
    } else {
      homeScreen = const SplashPage();
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionManager.recordActivity(),
      onPointerMove: (_) => SessionManager.recordActivity(),
      onPointerHover: (_) => SessionManager.recordActivity(),
      onPointerPanZoomUpdate: (_) => SessionManager.recordActivity(),
      onPointerSignal: (_) => SessionManager.recordActivity(),
      child: MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        navigatorKey: SessionManager.navigatorKey,
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: homeScreen,
      ),
    );
  }
}
