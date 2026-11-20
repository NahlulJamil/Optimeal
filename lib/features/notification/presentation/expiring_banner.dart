import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Figma "Frame 37" (433:822): red warning card, e.g.
/// "Strawberry expiring soon / Find recipes to use them up".
///
/// Reusable by Developer 1 on Home (PRD §3.2 / §3.6 banner).
class ExpiringBanner extends StatelessWidget {
  const ExpiringBanner({
    super.key,
    required this.title,
    this.subtitle = 'Find recipes to use them up',
    this.onTap,
    this.tinted = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// `true` = pink card (Home banner); `false` = cream floating card.
  final bool tinted;

  /// "Strawberry expiring soon" or "3 items expiring soon".
  static String titleFor(List<String> names) => names.length == 1
      ? '${names.first} expiring soon'
      : '${names.length} items expiring soon';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tinted ? AppColors.dangerSoft : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: tinted ? 0 : 6,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
