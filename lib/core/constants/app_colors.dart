import 'package:flutter/material.dart';

/// Palet warna selaras dengan tema Web (Tailwind Sky & Slate)
class AppColors {
  // Primary Sky Palette (Identik dengan Web sky-600, sky-700, sky-100, sky-50)
  static const Color primary = Color(0xFF0284C7); // Sky 600
  static const Color primaryDark = Color(0xFF0369A1); // Sky 700
  static const Color primaryLight = Color(0xFFE0F2FE); // Sky 100
  static const Color primarySubtle = Color(0xFFF0F9FF); // Sky 50
  static const Color primaryContainer = Color(0xFFBAE6FD); // Sky 200
  static const Color primaryFocus = Color(0xFF0EA5E9); // Sky 500

  // Secondary Sky / Accents
  static const Color secondary = Color(0xFF0EA5E9); // Sky 500
  static const Color secondaryLight = Color(0xFFF0F9FF); // Sky 50
  static const Color accent = Color(0xFFF59E0B); // Amber 500 (Promo & Highlight)
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFF43F5E); // Rose 500 (Alert)

  // Backward compatibility alias for aqua -> mapped to modern Sky shades
  static const Color aqua = Color(0xFF0EA5E9); // Sky 500
  static const Color aquaDark = Color(0xFF0284C7); // Sky 600
  static const Color aquaLight = Color(0xFFF0F9FF); // Sky 50
  static const Color aquaMint = Color(0xFF0D9488); // Teal 600

  // Neutrals & Surfaces (Identik dengan Web Slate Palette)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceVariant = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceHighlight = Color(0xFFF0F9FF); // Sky 50
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderFocus = Color(0xFF0284C7); // Sky 600
  static const Color divider = Color(0xFFF1F5F9); // Slate 100
}
