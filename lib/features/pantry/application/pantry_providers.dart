import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/connectivity/sync_status.dart';
import '../../../core/models/food_item.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_pantry_repository.dart';
import '../data/pantry_repository.dart';
import '../data/photo_store.dart';
import '../domain/shelf_life.dart';

/// Fixtures in mock mode (`USE_MOCK`, the default), otherwise the signed-in
/// user's Firestore pantry. Rebuilt when the account changes, so one user's
/// pantry never shows for another.
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  if (AppConfig.useMock) return MockPantryRepository();
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const SignedOutPantryRepository();
  return FirestorePantryRepository(userId: user.uid);
});

final photoStoreProvider = Provider<PhotoStore>((ref) => PhotoStore());

/// All pantry items, sorted by the closest shelf-life estimate first
/// (PRD §3.4 "mengurutkan bahan berdasarkan estimasi masa simpan").
class PantryController extends AsyncNotifier<List<FoodItem>> {
  PantryRepository get _repo => ref.read(pantryRepositoryProvider);
  PhotoStore get _photos => ref.read(photoStoreProvider);

  @override
  Future<List<FoodItem>> build() async {
    // Rebuild when the account changes so one user's pantry never shows for
    // another.
    ref.watch(pantryRepositoryProvider);
    // Refresh when the connection returns, and mark the cached list as offline
    // as soon as the device loses its connection (PRD §7.5).
    ref.listen(onlineStatusProvider, (previous, next) {
      if (next) {
        unawaited(_refresh());
      } else {
        ref.read(syncStatusProvider.notifier).markOffline();
      }
    });
    return _fetch();
  }

  static List<FoodItem> _sorted(Iterable<FoodItem> items) =>
      [...items]..sort((a, b) {
        final byDate = a.estimatedEndDate.compareTo(b.estimatedEndDate);
        return byDate != 0
            ? byDate
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  /// Reads the pantry and reports the result to [syncStatusProvider].
  ///
  /// Writes happen only after `fetchAll` resolves: Riverpod forbids mutating
  /// another provider while this provider is still building synchronously.
  ///
  /// While offline the list comes from the device cache only, so Pantry opens
  /// read-only instead of waiting for a server that cannot answer (PRD §7.5).
  /// The status follows Firestore's `isFromCache`, not the connectivity plugin,
  /// so a cache read is never labelled as a fresh sync.
  Future<List<FoodItem>> _fetch() async {
    final online = ref.read(onlineStatusProvider);
    final sync = ref.read(syncStatusProvider.notifier);
    try {
      final read = await _repo.fetchAll(fromCache: !online);
      if (read.fromCache) {
        sync.markOffline();
      } else {
        sync.markSynced(DateTime.now());
      }
      return _sorted(read.items);
    } on Object {
      // A failed read while offline is still an offline state, not a server
      // error: the screen explains the connection instead (PRD §7.4).
      if (online) {
        sync.markError();
      } else {
        sync.markOffline();
      }
      rethrow;
    }
  }

  Future<void> _reload() async {
    ref.read(syncStatusProvider.notifier).markSyncing();
    state = AsyncData(await _fetch());
  }

  /// Best-effort refresh used when connectivity returns. Failures are shown in
  /// the list instead of being thrown into the connectivity listener.
  Future<void> _refresh() async {
    ref.read(syncStatusProvider.notifier).markSyncing();
    try {
      state = AsyncData(await _fetch());
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
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
