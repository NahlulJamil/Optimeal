import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';
import 'package:optimeal/features/recipes/domain/recipe_policy.dart';

final _now = DateTime.utc(2026, 11, 20, 12);

FoodItem _food(
  String id,
  String name,
  StorageLocation location, {
  num? quantity,
  String? unit,
}) => FoodItem(
  foodId: id,
  userId: 'u',
  name: name,
  category: 'Vegetable',
  quantity: quantity,
  unit: unit,
  storageLocation: location,
  purchaseDate: _now,
  shelfLifeDays: 5,
  estimatedEndDate: _now.add(const Duration(days: 5)),
  hasPhoto: false,
  createdAt: _now,
  updatedAt: _now,
);

Recipe _recipe(String id, {DateTime? accessed}) => Recipe(
  recipeId: id,
  name: id,
  description: 'd',
  illustrationKey: 'recipe_western_x',
  cuisine: 'Western',
  cookingTechnique: 'Saute',
  cookingTimeMinutes: 10,
  ingredientsAvailable: const ['a'],
  ingredientsMissing: const [],
  equipment: const [],
  steps: const ['s'],
  generatedAt: _now,
  lastAccessedAt: accessed ?? _now,
);

Map<String, Object?> _json({Map<String, Object?> override = const {}}) => {
  'recipeId': 'r_1',
  'name': 'Spinach Omelette',
  'description': 'Quick breakfast.',
  'cuisine': 'Western',
  'cookingTechnique': 'Pan-fry',
  'cookingTimeMinutes': 10,
  'ingredientsAvailable': ['200 g spinach'],
  'ingredientsMissing': ['Butter'],
  'equipment': ['Frying pan'],
  'steps': ['Beat the eggs.', 'Serve.'],
  ...override,
};

void main() {
  group('selectIngredients (location filter picks ingredients)', () {
    final pantry = [
      _food('1', 'Onion', StorageLocation.fridge),
      _food('2', 'Tomato', StorageLocation.fridge),
      _food('3', 'Rice', StorageLocation.roomTemperature),
      _food('4', 'Chicken', StorageLocation.freezer),
    ];

    test('only items from the chosen location are used', () {
      final r = selectIngredients(pantry, location: StorageLocation.fridge);
      expect(r.map((e) => e.name), ['Onion', 'Tomato']);
    });

    test('picked ingredients narrow the selection further', () {
      final r = selectIngredients(
        pantry,
        location: StorageLocation.fridge,
        pickedFoodIds: {'2', '3'},
      );
      expect(r.map((e) => e.name), ['Tomato']);
    });

    test('no location means everything', () {
      expect(selectIngredients(pantry), hasLength(4));
    });
  });

  group('ingredientFromFood (Contracts 4.4)', () {
    test('sends the enum value, not the UI label', () {
      final i = ingredientFromFood(
        _food('1', 'Rice', StorageLocation.roomTemperature),
      );
      expect(i.toJson()['storageLocation'], 'room_temperature');
    });

    test('quantity without unit is not sent', () {
      final i = ingredientFromFood(
        _food('1', 'Egg', StorageLocation.fridge, quantity: 6),
      );
      expect(i.quantity, isNull);
      expect(i.unit, isNull);
    });

    test('quantity with unit is sent', () {
      final i = ingredientFromFood(
        _food('1', 'Spinach', StorageLocation.fridge, quantity: 200, unit: 'g'),
      );
      expect(i.quantity, 200);
      expect(i.unit, 'g');
    });
  });

  group('pruneRecipeCache (PRD 3.5)', () {
    test('drops recipes not opened for more than 7 days', () {
      final r = pruneRecipeCache([
        _recipe('fresh', accessed: _now.subtract(const Duration(days: 6))),
        _recipe('stale', accessed: _now.subtract(const Duration(days: 8))),
      ], now: _now);
      expect(r.map((e) => e.recipeId), ['fresh']);
    });

    test('keeps at most 10, evicting the least recently accessed', () {
      final recipes = [
        for (var i = 0; i < 12; i++)
          _recipe('r$i', accessed: _now.subtract(Duration(hours: i))),
      ];
      final r = pruneRecipeCache(recipes, now: _now);
      expect(r, hasLength(10));
      expect(r.first.recipeId, 'r0');
      expect(r.map((e) => e.recipeId), isNot(contains('r10')));
      expect(r.map((e) => e.recipeId), isNot(contains('r11')));
    });
  });

  group('checkGenerateQuota (10/hour, 30/day)', () {
    test('allows 9 requests in an hour and blocks the 10th attempt', () {
      final nine = [
        for (var i = 0; i < 9; i++) _now.subtract(Duration(minutes: i + 1)),
      ];
      expect(checkGenerateQuota(nine, now: _now).allowed, isTrue);
      final ten = [...nine, _now.subtract(const Duration(minutes: 20))];
      final q = checkGenerateQuota(ten, now: _now);
      expect(q.allowed, isFalse);
      expect(q.retryAfter, isNotNull);
      expect(q.retryAfter!.isAfter(_now), isTrue);
    });

    test('hourly window slides', () {
      final old = [
        for (var i = 0; i < 10; i++) _now.subtract(const Duration(minutes: 90)),
      ];
      expect(checkGenerateQuota(old, now: _now).allowed, isTrue);
    });

    test('blocks after 30 in a day even when the hour is clear', () {
      final times = [
        for (var i = 0; i < 30; i++)
          _now.subtract(Duration(hours: 2, minutes: i)),
      ];
      final q = checkGenerateQuota(times, now: _now);
      expect(q.allowed, isFalse);
    });
  });

  group('Recipe.tryParse (client-side AI validation)', () {
    test('accepts the contract example and fills missing fields', () {
      final r = Recipe.tryParse(_json(), now: _now)!;
      expect(r.recipeId, 'r_1');
      expect(r.illustrationKey, 'recipe_western');
      expect(r.generatedAt, _now);
      expect(r.allIngredients, ['200 g spinach', 'Butter']);
    });

    test('rejects missing name, empty steps, bad time, no ingredients', () {
      expect(
        Recipe.tryParse(_json(override: {'name': ' '}), now: _now),
        isNull,
      );
      expect(
        Recipe.tryParse(_json(override: {'steps': <String>[]}), now: _now),
        isNull,
      );
      expect(
        Recipe.tryParse(_json(override: {'cookingTimeMinutes': 0}), now: _now),
        isNull,
      );
      expect(
        Recipe.tryParse(
          _json(
            override: {
              'ingredientsAvailable': <String>[],
              'ingredientsMissing': <String>[],
            },
          ),
          now: _now,
        ),
        isNull,
      );
    });

    test('round-trips through JSON', () {
      final r = Recipe.tryParse(_json(), now: _now)!;
      final again = Recipe.tryParse(r.toJson(), now: _now)!;
      expect(again.toJson(), r.toJson());
    });
  });

  test('illustrationKeyFor uses the cuisine, never a URL', () {
    expect(illustrationKeyFor('Japanese'), 'recipe_japanese');
    expect(illustrationKeyFor('Martian'), 'recipe_general');
  });
}
