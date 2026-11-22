import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema global Optimeal — light theme only, tipografi Inter sesuai Figma.
abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.uiFont,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppTextStyles.uiFont,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: AppTextStyles.uiFont,
          fontSize: 14,
          color: AppColors.surface,
        ),
      ),
    );
  }
}
