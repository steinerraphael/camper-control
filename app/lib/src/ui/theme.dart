import 'package:flutter/material.dart';

/// Dark on purpose: the app is mostly used in a van at night, and a bright
/// screen in a dark cabin is unpleasant for everyone in it.
abstract final class AppColors {
  static const bg0 = Color(0xFF0A0F1C);
  static const bg1 = Color(0xFF111A2E);
  static const glass = Color(0x0FFFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);
  static const text = Color(0xFFEFF3FA);
  static const muted = Color(0xFF8B95A9);

  static const teal = Color(0xFF2DD4BF);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
  static const blue = Color(0xFF60A5FA);
  static const violet = Color(0xFFA78BFA);
  static const cyan = Color(0xFF22D3EE);
  static const orange = Color(0xFFFB923C);
  static const pink = Color(0xFFF472B6);
}

/// Two-stop gradients for the status card: the one place with strong colour.
abstract final class Gradients {
  static const ok = [Color(0xFF10B981), Color(0xFF0EA5A4)];
  static const demo = [Color(0xFF8B5CF6), Color(0xFF6366F1)];
  static const bad = [Color(0xFFEF4444), Color(0xFFF97316)];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: Brightness.dark,
    surface: AppColors.bg1,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg0,
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF1E293B),
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg1,
      showDragHandle: true,
    ),
  );
}

/// German number formatting without pulling in intl for one comma.
String fmt(double? v, int digits, {bool signed = false}) {
  if (v == null) return '–';
  final rounded = double.parse(v.toStringAsFixed(digits));
  final text = (rounded == 0 ? 0.0 : rounded).abs().toStringAsFixed(digits).replaceAll('.', ',');
  if (rounded < 0) return '−$text';
  return signed && rounded > 0 ? '+$text' : text;
}
