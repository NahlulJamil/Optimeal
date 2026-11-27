import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/online_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/recipe_providers.dart';
import '../domain/recipe.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipe_picture.dart';

/// Recipe detail (Figma "recipes" 423:81 / 433:525 / 433:600): picture with
/// back and delete buttons, name, description, Cooking Time + Cuisine cards,
/// and the Ingredients / Equipment / Instructions tabs.
///
/// A favorite opens from its local snapshot, so this screen also works offline
/// (PRD §3.8); only favoriting and deleting need a connection.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Opening a recipe counts as access for cache eviction (PRD §3.5).
    unawaited(
      Future<void>.microtask(
        () =>
            ref.read(recipesControllerProvider.notifier).touch(widget.recipeId),
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final online = ref.read(onlineStatusProvider);
    if (!online) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(offlineActionMessage)));
      return;
    }
    final isFavorite =
        ref
            .read(recipesControllerProvider)
            .value
            ?.isFavorite(recipe.recipeId) ??
        false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text(
          isFavorite
              ? '"${recipe.name}" will be removed from your recipes and from '
                    'your favorites. This cannot be undone.'
              : '"${recipe.name}" will be removed from your recipes. This '
                    'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(recipesControllerProvider.notifier)
          .deleteRecipe(recipe.recipeId);
      navigator.pop();
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(recipeErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(recipesControllerProvider).value;
    final recipe = data?.find(widget.recipeId);
    final online = ref.watch(onlineStatusProvider);

    if (recipe == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Recipe'),
              const Expanded(
                child: StateMessage(
                  icon: Icons.menu_book_outlined,
                  title: 'This recipe is no longer available',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isFavorite = data?.isFavorite(recipe.recipeId) ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            RecipePicture(recipe: recipe, height: 400),
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 360),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height - 360,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        FavoriteButton(
                          recipe: recipe,
                          isFavorite: isFavorite,
                          enabled: online,
                          size: 40,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recipe.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.schedule,
                            label: 'Cooking Time',
                            value: '${recipe.cookingTimeMinutes} min',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.restaurant,
                            label: 'Cuisine',
                            value: recipe.cuisine,
                          ),
                        ),
                      ],
                    ),
                    if (recipe.cookingTechnique.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Technique: ${recipe.cookingTechnique}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Tabs(
                      selected: _tab,
                      onSelected: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 12),
                    _TabBody(tab: _tab, recipe: recipe),
                    const SizedBox(height: 16),
                    const Text(
                      'Recipes are AI suggestions. Check that your food is '
                      'still good before cooking.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    RecipePhotoCredit(recipe: recipe),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    CircleIconButton(
                      icon: Icons.close,
                      tooltip: online ? 'Delete recipe' : offlineActionMessage,
                      onPressed: () => _confirmDelete(recipe),
                      foreground: online
                          ? AppColors.textPrimary
                          : AppColors.navInactive,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['Ingredients', 'Equipment', 'Instructions'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: selected == i
                          ? AppColors.textPrimary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected == i
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.recipe});

  final int tab;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final lines = switch (tab) {
      0 => [
        ...recipe.ingredientsAvailable,
        for (final m in recipe.ingredientsMissing) '$m (to prepare)',
      ],
      1 => recipe.equipment,
      _ => recipe.steps,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: lines.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Nothing listed.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lines[i],
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
