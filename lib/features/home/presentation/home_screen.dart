import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/online_status.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../notification/application/notification_providers.dart';
import '../../notification/presentation/expiring_banner.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../pantry/presentation/widgets/food_list_tile.dart';
import '../../recipes/application/recipe_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/widgets/recipe_picture.dart';
import '../application/home_providers.dart';

/// Figma frame "home" (293:27): greeting, storage summary, expiring banner,
/// Pantry preview and one AI recipe (PRD §3.2).
///
/// Navigation is owned by the shell: this screen only reports taps through the
/// callbacks so it can also run on its own in widget tests.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onOpenPantry,
    this.onOpenRecipes,
    this.onOpenFood,
    this.onOpenRecipe,
  });

  final VoidCallback? onOpenPantry;
  final VoidCallback? onOpenRecipes;
  final ValueChanged<String>? onOpenFood;
  final ValueChanged<String>? onOpenRecipe;

  static const _summaryOrder = [
    StorageLocation.roomTemperature,
    StorageLocation.fridge,
    StorageLocation.freezer,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pantrySummaryProvider);
    final pantryItems = ref.watch(homePantryItemsProvider);
    final recipe = ref.watch(homeRecipeProvider);
    final expiring = ref.watch(expiringSoonProvider);
    final online = ref.watch(onlineStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 37),
          children: [
            _Header(
              kitchenName: ref.watch(kitchenNameProvider),
              online: online,
              onReminders: () => _showReminders(context, ref),
            ),
            // Figma: header bottom padding 24 is the gap to the summary card.
            const SizedBox(height: 24),
            _SummaryCard(summary: summary, order: _summaryOrder),
            if (expiring.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpiringBanner(
                title: ExpiringBanner.titleFor(expiring.length),
                tinted: true,
                onTap: onOpenRecipes,
              ),
            ],
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Pantry',
              onViewAll: onOpenPantry,
              viewAllKey: const Key('home-pantry-view-all'),
            ),
            const SizedBox(height: 10),
            ..._pantrySection(ref, pantryItems, onOpenFood),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'AI Recipe Recommendations',
              onViewAll: onOpenRecipes,
              viewAllKey: const Key('home-recipes-view-all'),
            ),
            const SizedBox(height: 12),
            ..._recipeSection(ref, recipe, onOpenRecipe),
          ],
        ),
      ),
    );
  }

  List<Widget> _pantrySection(
    WidgetRef ref,
    AsyncValue<List<FoodItem>> items,
    ValueChanged<String>? onOpenFood,
  ) {
    return items.when(
      loading: () => const [_SectionLoading(height: 72)],
      error: (_, _) => [
        _SectionError(
          message: 'Could not load your pantry.',
          onRetry: () => ref.invalidate(pantryControllerProvider),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return const [
            _EmptyCard(
              icon: Icons.kitchen_outlined,
              title: 'Your pantry is empty',
              message: 'Scan or add food to start tracking it.',
            ),
          ];
        }
        return [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            FoodListTile(
              item: list[i],
              onTap: onOpenFood == null
                  ? null
                  : () => onOpenFood(list[i].foodId),
            ),
          ],
        ];
      },
    );
  }

  List<Widget> _recipeSection(
    WidgetRef ref,
    AsyncValue<Recipe?> recipe,
    ValueChanged<String>? onOpenRecipe,
  ) {
    return recipe.when(
      loading: () => const [_SectionLoading(height: 112)],
      error: (_, _) => [
        _SectionError(
          message: 'Could not load recipe recommendations.',
          onRetry: () => ref.invalidate(recipesControllerProvider),
        ),
      ],
      data: (value) {
        if (value == null) {
          return const [
            _EmptyCard(
              icon: Icons.menu_book_outlined,
              title: 'No recipe recommendations yet',
              message: 'Generate recipes from the ingredients in your pantry.',
            ),
          ];
        }
        return [
          _HomeRecipeCard(
            recipe: value,
            onTap: onOpenRecipe == null
                ? null
                : () => onOpenRecipe(value.recipeId),
          ),
        ];
      },
    );
  }

  /// Bell icon: the items inside the reminder window, with their days left.
  void _showReminders(BuildContext context, WidgetRef ref) {
    final items = ref.read(expiringSoonProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reminders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  items.isEmpty
                      ? 'Nothing is close to its shelf-life estimate right now.'
                      : '${items.length} '
                            '${items.length == 1 ? 'item is' : 'items are'} '
                            'close to the shelf-life estimate.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const _EmptyCard(
                    icon: Icons.notifications_none,
                    title: 'No reminders right now',
                    message: 'We will remind you before an estimate ends.',
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => FoodListTile(
                        item: items[i],
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onOpenFood?.call(items[i].foodId);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.kitchenName,
    required this.online,
    required this.onReminders,
  });

  final String kitchenName;
  final bool online;
  final VoidCallback onReminders;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kitchenName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!online) ...[const _OfflinePill(), const SizedBox(width: 12)],
        IconButton(
          onPressed: onReminders,
          tooltip: 'Reminders',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          iconSize: 24,
          color: AppColors.primary,
          icon: const Icon(Icons.notifications),
        ),
      ],
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.statTile,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 13, color: AppColors.textSecondary),
          SizedBox(width: 5),
          Text(
            'Offline mode',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.order});

  final AsyncValue<HomeSummary> summary;
  final List<StorageLocation> order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 60,
                child: _StatTile(
                  location: order[i],
                  value: summary.when(
                    data: (data) => '${data.countFor(order[i])}',
                    loading: () => '–',
                    error: (_, _) => '–',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.location, required this.value});

  final StorageLocation location;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statTile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll, this.viewAllKey});

  final String title;
  final VoidCallback? onViewAll;
  final Key? viewAllKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onViewAll != null)
          InkWell(
            key: viewAllKey,
            onTap: onViewAll,
            child: const SizedBox(
              height: 19,
              child: Center(
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact Home recipe card (Figma 349:28): illustration, name, description,
/// up to two ingredient tags and the cooking time.
class _HomeRecipeCard extends StatelessWidget {
  const _HomeRecipeCard({required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[];
    for (final ingredient in recipe.ingredientsAvailable) {
      final label = ingredientTagLabel(ingredient);
      if (label.isEmpty) continue;
      tags.add(label);
      if (tags.length == 2) break;
    }
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: RecipePicture(
                  recipe: recipe,
                  height: 88,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        for (var i = 0; i < tags.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Flexible(child: _Tag(text: tags[i])),
                        ],
                        if (tags.isNotEmpty) const SizedBox(width: 8),
                        _Tag(text: '${recipe.cookingTimeMinutes} minute'),
                      ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tag,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
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
