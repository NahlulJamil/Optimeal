import 'package:material_ui/material_ui.dart';

/// Color tokens sampled from the Figma "Balomba" file (page HiFi Optimeal).
///
/// Nilai diambil langsung dari style resmi file Figma (bukan perkiraan):
/// `#FFFDF9` background, `#1A1D1A` teks utama, `#656C66` teks sekunder,
/// `#005B33` primary, `#EAE6DF` border, `#B83B32` error.
abstract final class AppColors {
  static const Color background = Color(0xFFFFFDF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF005B33);
  static const Color primarySoft = Color(0xFFEFF5EE);
  static const Color primaryTint = Color(0xFFEAFBEF);
  static const Color textPrimary = Color(0xFF1A1D1A);
  static const Color textSecondary = Color(0xFF656C66);
  static const Color textLabel = Color(0xFF1A1D1A);
  static const Color border = Color(0xFFEAE6DF);
  static const Color danger = Color(0xFFB83B32);
  static const Color dangerSoft = Color(0xFFFFF0ED);
  static const Color warning = Color(0xFFF2994A);

  /// Home summary tile (Figma "Room / Fridge / Chiller" cards, `#F8F7F2`).
  static const Color statTile = Color(0xFFF8F7F2);

  /// Recipe ingredient chip on Home (Figma `#F4F7F4`).
  static const Color tag = Color(0xFFF4F7F4);
  static const Color navInactive = Color(0xFF8E8E8E);
  static const Color scannerOverlay = Color(0xB3262624);
  static const Color glassButton = Color(0xCCE6E6E3);
}

/// Card shadow used by list rows and floating buttons in Figma.
const List<BoxShadow> appCardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];

/// Radius dan tinggi kontrol sesuai Figma: field 16, tombol utama 56 (pill).
const double kFieldRadius = 16;
const double kButtonHeight = 56;
