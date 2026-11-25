import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/pantry_providers.dart';
import '../domain/shelf_life.dart';
import 'food_form_screen.dart';
import 'formatters.dart';

/// Figma frame "Detail Food" (400:321). Opened from the Pantry list and from
/// notification deep links (`foodId`).
class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({super.key, required this.foodId});

  final String foodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantry = ref.watch(pantryControllerProvider);
    final item = ref.watch(foodItemProvider(foodId));
    // Connectivity alone is not enough: `writeBlockedProvider` also catches a
    // network without internet, where every Firestore write would fail.
    final canWrite = !ref.watch(writeBlockedProvider);

    Widget body;
    if (pantry.isLoading && item == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (item == null) {
      body = const StateMessage(
        icon: Icons.search_off,
        title: 'This food is no longer in your pantry',
      );
    } else {
      body = _DetailBody(item: item, canWrite: canWrite);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Detail Food'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item, required this.canWrite});

  final FoodItem item;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(foodPhotoProvider(item.foodId)).value;
    final condition = [
      item.visualCondition,
      item.aiNote,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          children: [
            FoodThumbnail(file: photo, size: 104, radius: 16),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.storageLocation.label,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('Food Information'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoPair(
                      label: 'Category',
                      value: normalizeCategory(item.category),
                    ),
                  ),
                  Expanded(
                    child: _InfoPair(
                      label: 'Quantity',
                      value: item.quantityLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Date Stored',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    formatDisplayDate(item.purchaseDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Estimated Shelf Life',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${item.shelfLifeDays} '
                    '${item.shelfLifeDays == 1 ? 'Day' : 'Days'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDisplayDate(item.purchaseDate)} – '
                '${formatDisplayDate(item.estimatedEndDate)} · from storage date',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Estimate only, not a freshness guarantee.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle('Food Condition'),
              const SizedBox(height: 10),
              Text(
                condition.isEmpty ? 'No condition notes.' : condition,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please inspect before consuming.',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Edit food details',
          onPressed: canWrite
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FoodFormScreen.edit(item: item),
                  ),
                )
              : null,
        ),
        if (!canWrite) const OfflineHint(offlineActionMessage),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: appCardShadow,
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
