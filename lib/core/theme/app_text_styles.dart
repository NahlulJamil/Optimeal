import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Skala tipografi dari Figma "Balomba" (page HiFi Optimeal).
///
/// Semua teks UI memakai **Inter**; wordmark "Optimeal" memakai **Lora**.
/// Ukuran dan berat di bawah ini disalin dari style resmi file Figma agar
/// layar auth sama dengan desain acuan (PRD §13.2 butir 2).
abstract final class AppTextStyles {
  static const String uiFont = 'Inter';
  static const String brandFont = 'Lora';

  /// Heading layar: Inter 28 ExtraBold, letter-spacing -0.6, line-height 120%.
  static const TextStyle heading = TextStyle(
    fontFamily: uiFont,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  /// Judul bagian (mis. "Pantry"): Inter 22 Bold.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: uiFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Deskripsi di bawah heading: Inter 15 Regular, line-height 150%.
  static const TextStyle body = TextStyle(
    fontFamily: uiFont,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Label field: Inter 14 SemiBold.
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: uiFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textLabel,
  );

  /// Isi field: Inter 15 Regular.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: uiFont,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Teks bantuan / error: Inter 12 Regular, line-height 150%.
  static const TextStyle helper = TextStyle(
    fontFamily: uiFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Teks tombol: Inter 16 Bold.
  static const TextStyle button = TextStyle(
    fontFamily: uiFont,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.surface,
  );

  /// Link teks (mis. "Forgot password?"): Inter 14 SemiBold primary.
  static const TextStyle link = TextStyle(
    fontFamily: uiFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// Teks kecil netral (mis. "New to Optimeal?"): Inter 14 Regular.
  static const TextStyle linkHint = TextStyle(
    fontFamily: uiFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );
}
