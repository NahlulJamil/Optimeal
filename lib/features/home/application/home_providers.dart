import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/food_item.dart';
import '../../auth/application/auth_providers.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../recipes/application/recipe_providers.dart';
import '../../recipes/domain/recipe.dart';

/// Jumlah bahan per lokasi penyimpanan untuk kartu ringkasan Home
/// (PRD §3.2). Urutan tampilan mengikuti enum: Pantry / Fridge / Freezer.
class HomeSummary {
  const HomeSummary({
    required this.pantry,
    required this.fridge,
    required this.freezer,
  });

  const HomeSummary.zero() : pantry = 0, fridge = 0, freezer = 0;

  final int pantry;
  final int fridge;
  final int freezer;

  int get total => pantry + fridge + freezer;

  int countFor(StorageLocation location) => switch (location) {
    StorageLocation.roomTemperature => pantry,
    StorageLocation.fridge => fridge,
    StorageLocation.freezer => freezer,
  };
}

/// Ringkasan isi Pantry. Membaca controller yang sama dengan layar Pantry,
/// jadi satu sumber data (DevelopmentPlan prinsip 6).
final pantrySummaryProvider = Provider<AsyncValue<HomeSummary>>((ref) {
  return ref.watch(pantryControllerProvider).whenData((items) {
    var pantry = 0;
    var fridge = 0;
    var freezer = 0;
    for (final item in items) {
      switch (item.storageLocation) {
        case StorageLocation.roomTemperature:
          pantry++;
        case StorageLocation.fridge:
          fridge++;
        case StorageLocation.freezer:
          freezer++;
      }
    }
    return HomeSummary(pantry: pantry, fridge: fridge, freezer: freezer);
  });
});

/// Maksimal 3 bahan dengan sisa hari paling sedikit (PRD §3.2). The Pantry
/// controller already sorts by `estimatedEndDate` ascending, so this only
/// takes the head of the list.
final homePantryItemsProvider = Provider<AsyncValue<List<FoodItem>>>((ref) {
  return ref
      .watch(pantryControllerProvider)
      .whenData((items) => items.take(3).toList(growable: false));
});

/// Maksimal 1 kartu AI Recipe Recommendation (PRD §3.2). The recipes
/// controller keeps the cache most recently opened first.
final homeRecipeProvider = Provider<AsyncValue<Recipe?>>((ref) {
  return ref
      .watch(recipesControllerProvider)
      .whenData((data) => data.recipes.isEmpty ? null : data.recipes.first);
});

/// "Sarah's Kitchen" from the account name (PRD §3.2). Falls back to
/// "My Kitchen" while the session is loading or when no name was saved.
final kitchenNameProvider = Provider<String>((ref) {
  final profileName = ref.watch(profileUserProvider)?.name.trim() ?? '';
  final authName = ref.watch(authStateProvider).value?.displayName?.trim() ?? '';
  final name = profileName.isNotEmpty ? profileName : authName;
  if (name.isEmpty) return 'My Kitchen';
  final firstName = name.split(RegExp(r'\s+')).first;
  return "$firstName's Kitchen";
});
