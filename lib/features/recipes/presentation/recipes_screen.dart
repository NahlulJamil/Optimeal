import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/online_status.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/recipe_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_policy.dart';
import 'recipe_detail_screen.dart';
import 'widgets/recipe_card.dart';

/// Recipe Finder (Figma "recipes" 293:310; PRD §3.5, §3.8).
///
/// Follows the Figma frame: header, Location + Cuisine dropdowns, ingredient
/// search with removable chips, and recipe cards. Two elements are required by
/// the PRD but not drawn in Figma yet (PRD §12.3 note 6): the
/// Recommended / Favorites switch and the Generate button.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, this.onBack});

  /// Back goes to Home; navigation is owned by Developer 1.
  final VoidCallback? onBack;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _generating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final filter = ref.read(recipeFilterProvider);
    final candidates = ref.read(recipeIngredientCandidatesProvider).value ?? [];
    final chosen = selectIngredients(
      candidates,
      location: filter.location,
      pickedFoodIds: filter.pickedFoodIds,
    );
    final messenger = ScaffoldMessenger.of(context);

    if (chosen.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'No food in ${filter.location.label} yet. Add food or choose '
              'another location.',
            ),
          ),
        );
      return;
    }

    setState(() => _generating = true);
    try {
      await ref
          .read(recipesControllerProvider.notifier)
          .generate(
            ingredients: [for (final f in chosen) ingredientFromFood(f)],
            cuisine: filter.cuisine,
          );
      if (mounted) {
        ref.read(recipeTabProvider.notifier).select(RecipeTab.recommended);
      }
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(recipeErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openRecipe(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(recipeId: recipe.recipeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reload recipes and favorites when the connection changes (PRD §4.7).
    ref.listen<bool>(onlineStatusProvider, (previous, next) {
      if (previous != next) ref.invalidate(recipesControllerProvider);
    });
    final filter = ref.watch(recipeFilterProvider);
    final tab = ref.watch(recipeTabProvider);
    final online = ref.watch(onlineStatusProvider);
    final data = ref.watch(recipesControllerProvider);
    final candidates = ref.watch(recipeIngredientCandidatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: 'Recipe', onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  _FilterRow(filter: filter),
                  const SizedBox(height: 16),
                  _IngredientSearch(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  ..._suggestions(candidates.value ?? const [], filter),
                  _PickedChips(
                    items: candidates.value ?? const [],
                    pickedIds: filter.pickedFoodIds,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Generate recipes',
                    busy: _generating,
                    onPressed: online ? _generate : null,
                  ),
                  if (!online)
                    const OfflineHint(
                      'You are offline. Generating recipes needs an '
                      'internet connection.',
                    ),
                  const SizedBox(height: 20),
                  _TabSwitch(
                    tab: tab,
                    onSelected: ref.read(recipeTabProvider.notifier).select,
                  ),
                  const SizedBox(height: 16),
                  ..._list(data, tab, online),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pantry matches for the search text; tapping one adds it as a chip.
  List<Widget> _suggestions(List<FoodItem> candidates, RecipeFilter filter) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = [
      for (final i in candidates)
        if (!filter.pickedFoodIds.contains(i.foodId) &&
            i.name.toLowerCase().contains(q))
          i,
    ];
    return [
      const SizedBox(height: 8),
      if (matches.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No "${_query.trim()}" in ${filter.location.label}.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (final item in matches.take(5))
                ListTile(
                  dense: true,
                  title: Text(item.name),
                  subtitle: Text(item.storageLocation.label),
                  trailing: const Icon(Icons.add, color: AppColors.primary),
                  onTap: () {
                    ref
                        .read(recipeFilterProvider.notifier)
                        .togglePicked(item.foodId);
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _list(AsyncValue<RecipesData> data, RecipeTab tab, bool online) {
    return data.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        StateMessage(
          icon: Icons.error_outline,
          title: 'Could not load recipes',
          message: 'Please try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(recipesControllerProvider),
            child: const Text('Try again'),
          ),
        ),
      ],
      data: (d) {
        final recipes = tab == RecipeTab.favorites
            ? [for (final f in d.favorites) f.recipeSnapshot]
            : d.recipes;
        if (recipes.isEmpty) {
          return [
            tab == RecipeTab.favorites
                ? const StateMessage(
                    icon: Icons.favorite_border,
                    title: 'No favorite recipes yet',
                    message:
                        'Tap the heart on a recipe to keep it here, '
                        'even when you are offline.',
                  )
                : StateMessage(
                    icon: Icons.menu_book_outlined,
                    title: 'No recipes yet',
                    message: online
                        ? 'Choose a location and tap Generate recipes.'
                        : 'Connect to the internet to generate recipes. '
                              'Your favorites are still available.',
                  ),
          ];
        }
        return [
          for (final r in recipes) ...[
            RecipeCard(recipe: r, onTap: () => _openRecipe(r)),
            const SizedBox(height: 16),
          ],
        ];
      },
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.filter});

  final RecipeFilter filter;

  /// Same order as the Pantry chips and the Figma dropdown.
  static const _locations = [
    StorageLocation.roomTemperature,
    StorageLocation.fridge,
    StorageLocation.freezer,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recipeFilterProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Labeled(
            label: 'Location',
            child: _Dropdown<StorageLocation>(
              value: filter.location,
              items: {for (final l in _locations) l: l.label},
              onChanged: (v) {
                if (v != null) notifier.setLocation(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Labeled(
            label: 'Cuisine',
            child: _Dropdown<String?>(
              value: filter.cuisine,
              items: {
                null: 'Any cuisine',
                for (final c in recipeCuisines) c: c,
              },
              onChanged: notifier.setCuisine,
            ),
          ),
        ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          items: [
            for (final e in items.entries)
              DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _IngredientSearch extends StatelessWidget {
  const _IngredientSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search specific ingredients...',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _PickedChips extends ConsumerWidget {
  const _PickedChips({required this.items, required this.pickedIds});

  final List<FoodItem> items;
  final Set<String> pickedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = [
      for (final i in items)
        if (pickedIds.contains(i.foodId)) i,
    ];
    if (picked.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in picked)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ref
                  .read(recipeFilterProvider.notifier)
                  .togglePicked(item.foodId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5F2DC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.close, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.tab, required this.onSelected});

  final RecipeTab tab;
  final ValueChanged<RecipeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget item(RecipeTab value, String label) {
      final selected = tab == value;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item(RecipeTab.recommended, 'Recommended'),
        item(RecipeTab.favorites, 'Favorites'),
      ],
    );
  }
}
