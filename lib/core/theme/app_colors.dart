import 'package:material_ui/material_ui.dart';

/// Color tokens sampled from the Figma "Balomba" file (page HiFi Optimeal).
///
/// The global theme, Dark Mode and typography are owned by Developer 1; these
/// tokens are the light-mode values used by Developer 2's screens and can be
/// moved into the shared theme without changing call sites.
abstract final class AppColors {
  static const Color background = Color(0xFFFEFDF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF005A32);
  static const Color primarySoft = Color(0xFFEFF5EE);
  static const Color primaryTint = Color(0xFFEAFBEF);
  static const Color textPrimary = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLabel = Color(0xFF5F6368);
  static const Color border = Color(0xFFE4E4E1);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDE8E7);
  static const Color warning = Color(0xFFF2994A);
  static const Color navInactive = Color(0xFF8E8E8E);
  static const Color scannerOverlay = Color(0xB3262624);
  static const Color glassButton = Color(0xCCE6E6E3);
}

/// Card shadow used by list rows and floating buttons in Figma.
const List<BoxShadow> appCardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];
