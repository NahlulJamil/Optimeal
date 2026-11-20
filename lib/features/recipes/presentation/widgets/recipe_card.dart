import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/connectivity/online_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/recipe_providers.dart';
import '../../domain/recipe.dart';
import 'recipe_illustration.dart';

/// Recipe card from Figma "recipes": picture, bold name, short description.
/// The favorite heart is the PRD §3.8 addition (not yet drawn in Figma).
class RecipeCard extends ConsumerWidget {
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(recipesControllerProvider).value;
    final isFavorite = data?.isFavorite(recipe.recipeId) ?? false;
    final online = ref.watch(onlineStatusProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RecipeIllustration(
                    illustrationKey: recipe.illustrationKey,
                    height: 150,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FavoriteButton(
                      recipe: recipe,
                      isFavorite: isFavorite,
                      enabled: online,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${recipe.description} Ready in '
                      '${recipe.cookingTimeMinutes} mins.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
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

/// Heart that adds / removes a favorite. Disabled while offline with an
/// explanation, never hidden (PRD §2.4).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.enabled,
    this.size = 36,
  });

  final Recipe recipe;
  final bool isFavorite;
  final bool enabled;
  final double size;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(recipesControllerProvider.notifier);
    try {
      if (isFavorite) {
        await controller.removeFavorite(recipe.recipeId);
      } else {
        await controller.addFavorite(recipe);
      }
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(recipeErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: enabled
          ? (isFavorite ? 'Remove from favorites' : 'Add to favorites')
          : offlineActionMessage,
      child: Material(
        color: AppColors.surface.withValues(alpha: enabled ? 0.92 : 0.6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => _toggle(context, ref) : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: size * 0.55,
              color: enabled
                  ? (isFavorite ? AppColors.danger : AppColors.textPrimary)
                  : AppColors.navInactive,
            ),
          ),
        ),
      ),
    );
  }
}
