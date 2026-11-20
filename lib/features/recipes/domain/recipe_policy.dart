import '../../../core/models/food_item.dart';
import 'recipe.dart';

/// Limits from PRD §11 / §3.5 / §3.8. Initial values, reviewable after
/// testing (PRD §12.3 note 4).
abstract final class RecipeLimits {
  static const int cacheMaxRecipes = 10;
  static const Duration cacheTtl = Duration(days: 7);
  static const int generatePerHour = 10;
  static const int generatePerDay = 30;
  static const int favoritesMax = 50;
}

/// One ingredient sent to `POST /generate-recipes` (Contracts §4.4).
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
  });

  final String name;
  final num? quantity;
  final String? unit;

  /// Enum value (`room_temperature` / `fridge` / `freezer`), not the label.
  final String storageLocation;

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'storageLocation': storageLocation,
  };
}

/// Chooses which pantry items are considered for a recipe search.
///
/// The location filter decides **which ingredients** are sent to the AI, not a
/// recipe attribute (PRD §3.5): with Fridge selected, pantry and freezer items
/// are ignored. When the user picked specific ingredients, only those are used
/// (still limited to the selected location).
List<FoodItem> selectIngredients(
  List<FoodItem> pantry, {
  StorageLocation? location,
  Set<String> pickedFoodIds = const {},
}) {
  return [
    for (final item in pantry)
      if ((location == null || item.storageLocation == location) &&
          (pickedFoodIds.isEmpty || pickedFoodIds.contains(item.foodId)))
        item,
  ];
}

/// `quantity` without `unit` is invalid (Contracts §3.1), so it is not sent.
RecipeIngredient ingredientFromFood(FoodItem item) {
  final hasUnit = item.unit != null && item.unit!.trim().isNotEmpty;
  return RecipeIngredient(
    name: item.name,
    quantity: hasUnit ? item.quantity : null,
    unit: hasUnit && item.quantity != null ? item.unit!.trim() : null,
    storageLocation: item.storageLocation.value,
  );
}

/// Cache rules (PRD §3.5): drop recipes not opened for 7 days, then keep at
/// most 10, evicting the least recently accessed first. Result is sorted with
/// the most recently accessed first.
///
/// A favorite keeps its own snapshot (PRD §3.8), so evicting it from the cache
/// never removes it from Favorites.
List<Recipe> pruneRecipeCache(
  Iterable<Recipe> recipes, {
  required DateTime now,
}) {
  final fresh = [
    for (final r in recipes)
      if (now.difference(r.lastAccessedAt) <= RecipeLimits.cacheTtl) r,
  ]..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
  if (fresh.length <= RecipeLimits.cacheMaxRecipes) return fresh;
  return fresh.sublist(0, RecipeLimits.cacheMaxRecipes);
}

/// Client-side generate limit: 10 per hour and 30 per day per user
/// (Contracts §6.5). Checked before the Worker is called.
class GenerateQuota {
  const GenerateQuota({required this.allowed, this.retryAfter});

  final bool allowed;

  /// When the next request becomes possible, if blocked.
  final DateTime? retryAfter;
}

GenerateQuota checkGenerateQuota(
  Iterable<DateTime> requestTimes, {
  required DateTime now,
}) {
  final day = [
    for (final t in requestTimes)
      if (now.difference(t) < const Duration(days: 1) && !t.isAfter(now)) t,
  ]..sort();
  final hour = [
    for (final t in day)
      if (now.difference(t) < const Duration(hours: 1)) t,
  ];

  DateTime? retry;
  if (hour.length >= RecipeLimits.generatePerHour) {
    retry = hour[hour.length - RecipeLimits.generatePerHour].add(
      const Duration(hours: 1),
    );
  }
  if (day.length >= RecipeLimits.generatePerDay) {
    final dayRetry = day[day.length - RecipeLimits.generatePerDay].add(
      const Duration(days: 1),
    );
    if (retry == null || dayRetry.isAfter(retry)) retry = dayRetry;
  }
  return GenerateQuota(allowed: retry == null, retryAfter: retry);
}

/// Keeps only the timestamps that can still matter (last 24 hours).
List<DateTime> pruneRequestTimes(
  Iterable<DateTime> times, {
  required DateTime now,
}) => [
  for (final t in times)
    if (now.difference(t) < const Duration(days: 1)) t,
];
