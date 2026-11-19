import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/presentation/food_form_entry.dart';

import '../helpers/fakes.dart';

void main() {
  late ProviderContainer container;
  late MemoryPhotoStore photos;

  setUp(() {
    photos = MemoryPhotoStore();
    container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
        photoStoreProvider.overrideWithValue(photos),
      ],
    );
    addTearDown(container.dispose);
  });

  test('loads fixtures sorted by the closest estimate first', () async {
    final items = await container.read(pantryControllerProvider.future);
    expect(items, hasLength(5));
    expect(items.map((i) => i.foodId), [
      'f_001',
      'f_002',
      'f_003',
      'f_004',
      'f_005',
    ]);
  });

  test('filters by location, name search and category', () async {
    final items = await container.read(pantryControllerProvider.future);
    expect(applyPantryFilter(items, const PantryFilter()).map((i) => i.name), [
      'Strawberries',
      'Baby Spinach',
      'Whole Milk',
      'Greek Yogurt',
    ]);
    expect(
      applyPantryFilter(
        items,
        const PantryFilter(location: StorageLocation.roomTemperature),
      ).single.name,
      'Banana',
    );
    expect(
      applyPantryFilter(items, const PantryFilter(query: 'MILK')).single.name,
      'Whole Milk',
    );
    expect(
      applyPantryFilter(
        items,
        const PantryFilter(category: 'Dairy'),
      ).map((i) => i.name),
      ['Whole Milk', 'Greek Yogurt'],
    );
  });

  test('add computes estimatedEndDate and stores the photo locally', () async {
    await container.read(pantryControllerProvider.future);
    final item = await container
        .read(pantryControllerProvider.notifier)
        .add(
          FoodDraft(
            name: ' Pear ',
            category: 'Fruits',
            storageLocation: StorageLocation.fridge,
            purchaseDate: DateTime(2026, 11, 20),
            shelfLifeDays: 6,
            hasPhoto: true,
          ),
          photo: Uint8ListHelper.bytes,
        );
    expect(item.name, 'Pear');
    expect(item.estimatedEndDate, DateTime(2026, 11, 26));
    expect(photos.saved.keys, [item.foodId]);
    expect(container.read(pantryControllerProvider).value, hasLength(6));
  });

  test('edit recomputes the end date; quantity does not change it', () async {
    final items = await container.read(pantryControllerProvider.future);
    final strawberries = items.first;

    final entry = FoodFormEntry.fromItem(strawberries)
      ..quantityText = '3 punnet';
    expect(entry.shelfLifeDays, strawberries.shelfLifeDays);

    entry.purchaseDate = DateTime(2026, 11, 15);
    final updated = await container
        .read(pantryControllerProvider.notifier)
        .edit(entry.applyTo(strawberries));

    expect(updated.quantity, 3);
    expect(updated.shelfLifeDays, 4);
    expect(updated.estimatedEndDate, DateTime(2026, 11, 19));
  });

  test('delete removes the item and its photo', () async {
    await container.read(pantryControllerProvider.future);
    photos.saved['f_001'] = Uint8ListHelper.bytes;
    await container.read(pantryControllerProvider.notifier).remove('f_001');
    expect(
      container.read(pantryControllerProvider).value!.map((i) => i.foodId),
      isNot(contains('f_001')),
    );
    expect(photos.saved, isEmpty);
  });

  group('FoodFormEntry', () {
    FoodFormEntry entry() => FoodFormEntry(
      name: 'Pear',
      category: 'Fruit',
      location: StorageLocation.fridge,
      purchaseDate: DateTime(2026, 11, 20),
      estimate: const ShelfLifeEstimate(
        roomTemperature: 3,
        fridge: 6,
        freezer: 90,
      ),
    );

    test('changing location re-selects the estimate', () {
      final e = entry();
      expect(e.category, 'Fruits');
      expect(e.shelfLifeDays, 6);
      e.location = StorageLocation.roomTemperature;
      expect(e.shelfLifeDays, 3);
    });

    test('a manual end date survives location changes', () {
      final e = entry()..setEstimatedEndDate(DateTime(2026, 11, 30));
      expect(e.shelfLifeDays, 10);
      e.location = StorageLocation.freezer;
      expect(e.shelfLifeDays, 10);
      expect(
        () => e.setEstimatedEndDate(DateTime(2026, 11, 20)),
        throwsArgumentError,
      );
    });

    test('validates name and quantity with unit', () {
      final e = entry();
      expect(e.validate(), isNull);
      e.quantityText = '2';
      expect(e.validate(), contains('unit'));
      e.quantityText = '1,5 kg';
      expect(e.validate(), isNull);
      expect(e.toDraft().quantity, 1.5);
      expect(e.toDraft().unit, 'kg');
      e.name = '  ';
      expect(e.validate(), 'Food name is required.');
    });
  });
}

abstract final class Uint8ListHelper {
  static final bytes = Uint8List.fromList([1, 2, 3]);
}
