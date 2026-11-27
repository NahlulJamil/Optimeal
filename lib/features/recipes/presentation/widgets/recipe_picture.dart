import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/recipe_providers.dart';
import '../../domain/recipe.dart';
import 'recipe_illustration.dart';

/// The food photo of a recipe (PRD §6.3). Shows [RecipeIllustration] while
/// there is none: loading, offline, not found or failed.
class RecipePicture extends ConsumerWidget {
  const RecipePicture({
    super.key,
    required this.recipe,
    this.height = 160,
    this.borderRadius = BorderRadius.zero,
  });

  final Recipe recipe;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(recipePhotoProvider(photoQueryFor(recipe))).value;
    final fallback = RecipeIllustration(
      illustrationKey: recipe.illustrationKey,
      height: height,
      borderRadius: borderRadius,
    );
    if (photo == null) return fallback;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.file(
        photo.file,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: 'Photo for ${recipe.name}',
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Author and license of the photo; empty when no photo is shown.
class RecipePhotoCredit extends ConsumerWidget {
  const RecipePhotoCredit({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(recipePhotoProvider(photoQueryFor(recipe))).value;
    if (photo == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        photo.credit,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
