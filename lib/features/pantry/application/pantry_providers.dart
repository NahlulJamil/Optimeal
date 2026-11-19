import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/food_item.dart';
import '../data/pantry_repository.dart';
import '../data/photo_store.dart';
import '../domain/shelf_life.dart';

final pantryRepositoryProvider = Provider<PantryRepository>(
  (ref) => MockPantryRepository(),
);

final photoStoreProvider = Provider<PhotoStore>((ref) => PhotoStore());

/// All pantry items, sorted by the closest shelf-life estimate first
/// (PRD §3.4 "mengurutkan bahan berdasarkan estimasi masa simpan").
class PantryController extends AsyncNotifier<List<FoodItem>> {
  PantryRepository get _repo => ref.read(pantryRepositoryProvider);
  PhotoStore get _photos => ref.read(photoStoreProvider);

  @override
  Future<List<FoodItem>> build() async => _sorted(await _repo.fetchAll());

  static List<FoodItem> _sorted(Iterable<FoodItem> items) =>
      [...items]..sort((a, b) {
        final byDate = a.estimatedEndDate.compareTo(b.estimatedEndDate);
        return byDate != 0
            ? byDate
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  Future<void> _reload() async {
    state = AsyncData(_sorted(await _repo.fetchAll()));
  }

  /// Saves a new item, then its photo on the device.
  Future<FoodItem> add(FoodDraft draft, {Uint8List? photo}) async {
    final item = await _repo.add(draft);
    if (photo != null) await _photos.save(item.foodId, photo);
    await _reload();
    return item;
  }

  Future<FoodItem> edit(FoodItem item) async {
    final updated = await _repo.update(item);
    await _reload();
    return updated;
  }

  Future<void> remove(String foodId) async {
    await _repo.delete(foodId);
    await _photos.delete(foodId);
    await _reload();
  }
}

final pantryControllerProvider =
    AsyncNotifierProvider<PantryController, List<FoodItem>>(
      PantryController.new,
    );

/// Search + filter state for the Pantry screen.
class PantryFilter {
  const PantryFilter({
    this.location = StorageLocation.fridge,
    this.query = '',
    this.category,
  });

  /// Figma shows Fridge / Pantry / Freezer chips with Fridge selected.
  final StorageLocation location;
  final String query;

  /// Category filter (PRD §3.4). The Figma Pantry frame has no control for
  /// it yet; supported here so the UI can be wired once it is designed.
  final String? category;

  PantryFilter copyWith({
    StorageLocation? location,
    String? query,
    String? Function()? category,
  }) => PantryFilter(
    location: location ?? this.location,
    query: query ?? this.query,
    category: category != null ? category() : this.category,
  );
}

class PantryFilterController extends Notifier<PantryFilter> {
  @override
  PantryFilter build() => const PantryFilter();

  void setLocation(StorageLocation location) =>
      state = state.copyWith(location: location);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setCategory(String? category) =>
      state = state.copyWith(category: () => category);
}

final pantryFilterProvider =
    NotifierProvider<PantryFilterController, PantryFilter>(
      PantryFilterController.new,
    );

/// Applies [filter] to [items]; keeps the shelf-life sort order.
List<FoodItem> applyPantryFilter(List<FoodItem> items, PantryFilter filter) {
  final q = filter.query.trim().toLowerCase();
  return items.where((i) {
    if (i.storageLocation != filter.location) return false;
    if (filter.category != null &&
        normalizeCategory(i.category) != filter.category) {
      return false;
    }
    return q.isEmpty || i.name.toLowerCase().contains(q);
  }).toList();
}

final filteredPantryProvider = Provider<AsyncValue<List<FoodItem>>>((ref) {
  final filter = ref.watch(pantryFilterProvider);
  return ref
      .watch(pantryControllerProvider)
      .whenData((items) => applyPantryFilter(items, filter));
});

/// Local photo for a food item, or `null` when this device has none.
final foodPhotoProvider = FutureProvider.family<File?, String>((
  ref,
  foodId,
) async {
  // Refresh when the pantry changes (e.g. a photo was added or deleted).
  ref.watch(pantryControllerProvider);
  return ref.read(photoStoreProvider).find(foodId);
});

final foodItemProvider = Provider.family<FoodItem?, String>((ref, foodId) {
  final items = ref.watch(pantryControllerProvider).value;
  if (items == null) return null;
  for (final i in items) {
    if (i.foodId == foodId) return i;
  }
  return null;
});
