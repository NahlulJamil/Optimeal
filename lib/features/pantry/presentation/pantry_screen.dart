import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/models/food_item.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/sync_status_line.dart';
import '../application/pantry_providers.dart';
import 'food_detail_screen.dart';
import 'widgets/food_list_tile.dart';

/// Figma frame "pantry" (293:128): search, location chips, sorted list.
class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key, this.onBack});

  /// Back goes to Home; Home/navigation is owned by Developer 1.
  final VoidCallback? onBack;

  /// Chip order from Figma.
  static const _chipOrder = [
    StorageLocation.fridge,
    StorageLocation.roomTemperature,
    StorageLocation.freezer,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pantryFilterProvider);
    final items = ref.watch(filteredPantryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: 'Pantry', onBack: onBack),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: _SearchField(
                onChanged: ref.read(pantryFilterProvider.notifier).setQuery,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Wrap(
                spacing: 10,
                children: [
                  for (final l in _chipOrder)
                    _LocationChip(
                      label: l.label,
                      selected: filter.location == l,
                      onTap: () => ref
                          .read(pantryFilterProvider.notifier)
                          .setLocation(l),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SyncStatusLine(),
              ),
            ),
            Expanded(
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _errorState(ref),
                data: (list) {
                  if (list.isEmpty) {
                    return StateMessage(
                      icon: Icons.kitchen_outlined,
                      title: filter.query.isEmpty
                          ? 'No food in ${filter.location.label} yet'
                          : 'No food matches "${filter.query}"',
                      message: filter.query.isEmpty
                          ? (ref.watch(syncStatusProvider).phase ==
                                    SyncPhase.offline
                                ? 'Adding food needs an internet connection.'
                                : 'Scan or add food to start tracking it.')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => FoodListTile(
                      item: list[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FoodDetailScreen(foodId: list[i].foodId),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Offline failures read as "no connection" instead of a broken app
  /// (PRD §7.4: a sync failure is a status, not a blocking error).
  Widget _errorState(WidgetRef ref) {
    final offline =
        ref.watch(syncStatusProvider).phase == SyncPhase.offline;
    return StateMessage(
      icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
      title: offline
          ? 'Pantry is unavailable offline'
          : 'Could not load your pantry',
      message: offline
          ? 'Reconnect to load your ingredients.'
          : 'Please try again.',
      action: OutlinedButton(
        onPressed: () => ref.invalidate(pantryControllerProvider),
        child: const Text('Try again'),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search ingredients...',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search, color: AppColors.textLabel),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
