import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// Stand-in while a recipe has no generated picture (PRD §6.3): a tinted tile with
/// an icon chosen by cuisine from [illustrationKey] (`recipe_<cuisine>[_name]`).
/// It is built in, so it also shows offline.
class RecipeIllustration extends StatelessWidget {
  const RecipeIllustration({
    super.key,
    required this.illustrationKey,
    this.height = 160,
    this.borderRadius = BorderRadius.zero,
  });

  final String illustrationKey;
  final double height;
  final BorderRadius borderRadius;

  /// `recipe_western_pasta` → `western`; unknown keys → `general`.
  static String cuisineOf(String key) {
    final parts = key.split('_');
    return parts.length >= 2 ? parts[1] : 'general';
  }

  static ({Color color, IconData icon}) styleFor(String cuisine) =>
      switch (cuisine) {
        'indonesian' => (color: const Color(0xFFF6D9A8), icon: Icons.rice_bowl),
        'italian' => (
          color: const Color(0xFFF4C7B8),
          icon: Icons.dinner_dining,
        ),
        'chinese' => (color: const Color(0xFFF2B8B5), icon: Icons.ramen_dining),
        'japanese' => (color: const Color(0xFFD7E3F4), icon: Icons.set_meal),
        'korean' => (color: const Color(0xFFE9CFE6), icon: Icons.soup_kitchen),
        'western' => (color: const Color(0xFFCFE6D2), icon: Icons.lunch_dining),
        _ => (color: AppColors.primarySoft, icon: Icons.restaurant_menu),
      };

  @override
  Widget build(BuildContext context) {
    final style = styleFor(cuisineOf(illustrationKey));
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: style.color,
          child: Center(
            child: Icon(
              style.icon,
              size: height * 0.38,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
