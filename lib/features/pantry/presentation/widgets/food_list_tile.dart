import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/food_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../application/pantry_providers.dart';
import '../../domain/shelf_life.dart';

/// Pantry row from Figma: photo, name, "qty • location", days-left badge.
class FoodListTile extends ConsumerWidget {
  const FoodListTile({super.key, required this.item, this.onTap, this.now});

  final FoodItem item;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(foodPhotoProvider(item.foodId)).value;
    final subtitle = [
      if (item.quantityLabel != '—') item.quantityLabel,
      item.storageLocation.label,
    ].join('  •  ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: appCardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                FoodThumbnail(file: photo, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DaysLeftBadge(days: daysLeft(item, now: now)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clock icon + "Use Today" / "N days left", colored by urgency.
class DaysLeftBadge extends StatelessWidget {
  const DaysLeftBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final color = switch (urgencyFor(days)) {
      ShelfUrgency.today => AppColors.danger,
      ShelfUrgency.soon => AppColors.warning,
      ShelfUrgency.fresh => AppColors.primary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          daysLeftLabel(days),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
