import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/domain/shelf_life.dart';

void main() {
  group('estimatedEndDate', () {
    test('is purchaseDate + shelfLifeDays', () {
      expect(
        computeEstimatedEndDate(DateTime(2026, 11, 7), 4),
        DateTime(2026, 11, 11),
      );
    });

    test('crosses month and year boundaries', () {
      expect(
        computeEstimatedEndDate(DateTime(2026, 12, 30), 3),
        DateTime(2027, 1, 2),
      );
    });
  });

  group('daysLeft / badge', () {
    FoodItem item(DateTime end) => FoodItem(
      foodId: 'f',
      userId: 'u',
      name: 'Milk',
      category: 'Dairy',
      storageLocation: StorageLocation.fridge,
      purchaseDate: DateTime(2026, 11, 1),
      shelfLifeDays: 1,
      estimatedEndDate: end,
      hasPhoto: false,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    final now = DateTime(2026, 11, 20, 15, 30);

    test('counts calendar days, ignoring the time of day', () {
      expect(daysLeft(item(DateTime(2026, 11, 22)), now: now), 2);
      expect(daysLeft(item(DateTime(2026, 11, 20)), now: now), 0);
      expect(daysLeft(item(DateTime(2026, 11, 18)), now: now), -2);
    });

    test('labels never say spoiled', () {
      expect(daysLeftLabel(0), 'Use Today');
      expect(daysLeftLabel(1), '1 day left');
      expect(daysLeftLabel(5), '5 days left');
      expect(daysLeftLabel(-1), 'Past estimate');
    });

    test('urgency colors follow the Figma rows', () {
      expect(urgencyFor(0), ShelfUrgency.today);
      expect(urgencyFor(2), ShelfUrgency.soon);
      expect(urgencyFor(3), ShelfUrgency.soon);
      expect(urgencyFor(5), ShelfUrgency.fresh);
    });
  });

  group('resolveShelfLifeDays', () {
    const estimate = ShelfLifeEstimate(
      roomTemperature: 1,
      fridge: 4,
      freezer: 30,
    );

    test('picks the value for the chosen location', () {
      expect(
        resolveShelfLifeDays(
          location: StorageLocation.freezer,
          estimate: estimate,
          category: 'Fruits',
        ),
        30,
      );
    });

    test('a manual value wins', () {
      expect(
        resolveShelfLifeDays(
          location: StorageLocation.freezer,
          estimate: estimate,
          category: 'Fruits',
          manualDays: 9,
        ),
        9,
      );
    });

    test('falls back to the catalog when the AI gave nothing valid', () {
      expect(
        resolveShelfLifeDays(
          location: StorageLocation.fridge,
          estimate: null,
          category: 'Fruit',
        ),
        fallbackShelfLifeCatalog['Fruits']!.fridge,
      );
    });
  });

  test('ShelfLifeEstimate.tryParse rejects missing or < 1 values', () {
    expect(
      ShelfLifeEstimate.tryParse({
        'room_temperature': 1,
        'fridge': 4,
        'freezer': 30,
      })?.fridge,
      4,
    );
    expect(
      ShelfLifeEstimate.tryParse({'room_temperature': 1, 'fridge': 4}),
      isNull,
    );
    expect(
      ShelfLifeEstimate.tryParse({
        'room_temperature': 0,
        'fridge': 4,
        'freezer': 30,
      }),
      isNull,
    );
    expect(ShelfLifeEstimate.tryParse('oops'), isNull);
  });

  test('normalizeCategory maps AI/fixture values to the Figma list', () {
    expect(normalizeCategory('Fruit'), 'Fruits');
    expect(normalizeCategory('vegetable'), 'Vegetables');
    expect(normalizeCategory('Dairy'), 'Dairy');
    expect(normalizeCategory('Unknown thing'), 'Others');
  });
}
