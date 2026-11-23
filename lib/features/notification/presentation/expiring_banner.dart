import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Figma "food-row" warning card (349:42): red card on Home, e.g.
/// "1 item expiring soon / Find recipes to use them up".
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

  /// "1 item expiring soon" / "3 items expiring soon" (PRD §3.2 counts the
  /// ingredients instead of naming one).
  static String titleFor(int count) =>
      count == 1 ? '1 item expiring soon' : '$count items expiring soon';

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
          padding: const EdgeInsets.fromLTRB(20, 17, 32, 17),
          child: Row(
            children: [
              Icon(
                tinted ? Icons.warning_rounded : Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.textSecondary,
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
