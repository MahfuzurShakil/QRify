import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Brand Colors (theme independent) ────────────────────────────────────────
class AppColors {
  // Premium palette — royal violet + champagne gold accents
  static const primary = Color(0xFF7C5CFF);
  static const primaryLight = Color(0xFFA894FF);
  static const primaryDark = Color(0xFF5A3FE0);
  static const accent = Color(0xFFFF6B9A);
  static const gold = Color(0xFFE9C46A);
  static const success = Color(0xFF2EE6A8);
  static const warning = Color(0xFFFFB547);
  static const error = Color(0xFFFF5C6C);
  static const lavender = Color(0xFFC3A6FF);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B6CFF), Color(0xFF5A3FE0)],
  );

  // Dark theme — deep midnight with a faint violet tint
  static const darkBgDeep = Color(0xFF0B0A12);
  static const darkBgCard = Color(0xFF16141F);
  static const darkBgElevated = Color(0xFF1E1C2B);
  static const darkBgHighlight = Color(0xFF282538);
  // Higher contrast text on black (WCAG AA+)
  static const darkTextPrimary = Color(0xFFF7F5FF);
  static const darkTextSecondary = Color(0xFFC4C0D6);
  static const darkTextMuted = Color(0xFFA29EB8);
  static const darkBorder = Color(0xFF302D42);
  static const darkBorderLight = Color(0xFF433F58);

  // Light theme
  static const lightBgDeep = Color(0xFFF6F4FC);
  static const lightBgCard = Color(0xFFFFFFFF);
  static const lightBgElevated = Color(0xFFEFECF9);
  static const lightBgHighlight = Color(0xFFE5E1F5);
  static const lightTextPrimary = Color(0xFF12101C);
  static const lightTextSecondary = Color(0xFF4A4660);
  static const lightTextMuted = Color(0xFF666180);
  static const lightBorder = Color(0xFFDCD7EE);
  static const lightBorderLight = Color(0xFFC8C2E0);

  static const surfaceWhite = Color(0xFFFAF9FF);

  // Shortcuts — theme aware (static getters, use via context extension instead)
  static const bgDeep = darkBgDeep;
  static const bgCard = darkBgCard;
  static const bgElevated = darkBgElevated;
  static const bgHighlight = darkBgHighlight;
  static const textPrimary = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textMuted = darkTextMuted;
  static const textDisabled = Color(0xFF6E6A85);
  static const border = darkBorder;
  static const borderLight = darkBorderLight;

  static const primaryGlow = Color(0x337C5CFF);
  static const primaryBorder = Color(0x557C5CFF);
  static const accentGlow = Color(0x33FF6B9A);
  static const accentBorder = Color(0x55FF6B9A);
  static const successGlow = Color(0x332EE6A8);
  static const successBorder = Color(0x552EE6A8);
  static const warningGlow = Color(0x33FFB547);
  static const warningBorder = Color(0x55FFB547);
}

// ─── Theme Provider ────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    _updateSystemUI();
    notifyListeners();
  }

  void setDark(bool value) {
    _isDark = value;
    _updateSystemUI();
    notifyListeners();
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          _isDark ? AppColors.darkBgCard : AppColors.lightBgCard,
      systemNavigationBarIconBrightness:
          _isDark ? Brightness.light : Brightness.dark,
    ));
  }
}

// ─── Theme Definitions ────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => _build(isDark: true);
  static ThemeData get light => _build(isDark: false);

  static ThemeData _build({required bool isDark}) {
    final bg = isDark ? AppColors.darkBgDeep : AppColors.lightBgDeep;
    final card = isDark ? AppColors.darkBgCard : AppColors.lightBgCard;
    final elevated =
        isDark ? AppColors.darkBgElevated : AppColors.lightBgElevated;
    final txtPri =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txtSec =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txtMut = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final brd = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: card,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: txtPri,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge:
            TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: txtPri),
        headlineLarge:
            TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: txtPri),
        headlineMedium:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: txtPri),
        headlineSmall:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: txtPri),
        bodyLarge: TextStyle(fontSize: 15, color: txtPri, height: 1.6),
        bodyMedium: TextStyle(fontSize: 13, color: txtSec, height: 1.5),
        bodySmall: TextStyle(fontSize: 11, color: txtMut, height: 1.4),
        labelLarge:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: txtPri),
        labelMedium:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: txtSec),
        labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: txtMut,
            letterSpacing: 1.0),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: txtPri),
        titleTextStyle:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: txtPri),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: brd, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brd, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brd, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: txtMut),
        labelStyle: TextStyle(color: txtSec),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(color: brd, thickness: 0.5, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: txtPri),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: brd, width: 0.5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Theme-aware color extension ──────────────────────────────────────────────
extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgDeep => isDark ? AppColors.darkBgDeep : AppColors.lightBgDeep;
  Color get bgCard => isDark ? AppColors.darkBgCard : AppColors.lightBgCard;
  Color get bgElevated =>
      isDark ? AppColors.darkBgElevated : AppColors.lightBgElevated;
  Color get bgHighlight =>
      isDark ? AppColors.darkBgHighlight : AppColors.lightBgHighlight;
  Color get txtPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get txtSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get txtMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  Color get borderColor =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;
}
