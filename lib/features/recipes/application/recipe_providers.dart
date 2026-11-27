import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/connectivity/online_status.dart';
import '../../../core/models/food_item.dart';
import '../../auth/application/auth_providers.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../scanner/application/scanner_providers.dart'
    show idTokenSourceProvider;
import '../../scanner/data/ai_client.dart';
import '../data/recipe_ai_client.dart';
import '../data/recipe_image_client.dart';
import '../data/recipe_image_store.dart';
import '../data/recipe_store.dart';
import '../domain/recipe.dart';
import '../domain/recipe_policy.dart';

/// Reason a recipe action was refused before or after reaching the server.
enum RecipeFailure { offline, quotaReached, favoriteLimit, signedOut }

class RecipeActionException implements Exception {
  const RecipeActionException(this.failure, {this.retryAfter});

  final RecipeFailure failure;

  /// For [RecipeFailure.quotaReached]: when generating becomes possible again.
  final DateTime? retryAfter;

  @override
  String toString() => 'RecipeActionException($failure)';
}

final recipeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Mock mode uses a fixed id; otherwise the signed-in user (or `null`).
final recipeUserIdProvider = Provider<String?>((ref) {
  if (AppConfig.useMock) return 'mock-user';
  return ref.watch(authStateProvider).value?.uid;
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Loads `assets/fixtures/recipes.json` (mock mode seed). Overridden in tests.
final recipeFixtureLoaderProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString('assets/fixtures/recipes.json'),
);

final recipeRemoteStoreProvider = Provider<RecipeRemoteStore?>((ref) {
  if (AppConfig.useMock) return MemoryRecipeRemoteStore();
  final uid = ref.watch(recipeUserIdProvider);
  if (uid == null) return null;
  return FirestoreRecipeRemoteStore(userId: uid);
});

final recipeAiClientProvider = Provider<RecipeAiClient>((ref) {
  if (AppConfig.useMock) return MockRecipeAiClient();
  return HttpRecipeAiClient(
    baseUrl: AppConfig.aiProxyUrl,
    idToken: ref.watch(idTokenSourceProvider),
  );
});

final recipeImageStoreProvider = Provider<RecipeImageStore>((ref) {
  return RecipeImageStore(
    client: AppConfig.useMock
        ? null
        : HttpRecipeImageClient(
            baseUrl: AppConfig.aiProxyUrl,
            idToken: ref.watch(idTokenSourceProvider),
          ),
  );
});

/// What the image of [recipe] is drawn from: names only, no amounts.
RecipeImageQuery imageQueryFor(Recipe recipe) => (
  recipeId: recipe.recipeId,
  name: recipe.name,
  cuisine: recipe.cuisine,
  ingredients: recipe.allIngredients
      .map(ingredientTagLabel)
      .where((label) => label.isNotEmpty)
      .take(8)
      .join(', '),
);

/// Image of a recipe, or `null` when none is available (PRD §6.3). Asked again
/// after the connection returns.
final recipeImageProvider = FutureProvider.autoDispose
    .family<File?, RecipeImageQuery>(
      (ref, query) => ref
          .watch(recipeImageStoreProvider)
          .load(query, online: ref.watch(onlineStatusProvider)),
    );

/// `true` when [id] can be used as a Firestore document id and cache key.
bool isSafeRecipeId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);

/// Cached recommendations plus favorites for the signed-in user.
class RecipesData {
  const RecipesData({this.recipes = const [], this.favorites = const []});

  /// Recommendation cache, most recently opened first (max 10).
  final List<Recipe> recipes;

  /// Favorites with their full snapshots, newest first (max 50).
  final List<FavoriteRecipe> favorites;

  bool isFavorite(String recipeId) =>
      favorites.any((f) => f.favoriteId == recipeId);

  Recipe? find(String recipeId) {
    for (final f in favorites) {
      if (f.favoriteId == recipeId) return f.recipeSnapshot;
    }
    for (final r in recipes) {
      if (r.recipeId == recipeId) return r;
    }
    return null;
  }

  RecipesData copyWith({
    List<Recipe>? recipes,
    List<FavoriteRecipe>? favorites,
  }) => RecipesData(
    recipes: recipes ?? this.recipes,
    favorites: favorites ?? this.favorites,
  );
}

class RecipesController extends AsyncNotifier<RecipesData> {
  RecipeRemoteStore? get _remote => ref.read(recipeRemoteStoreProvider);
  DateTime _now() => ref.read(recipeClockProvider)().toUtc();
  bool get _online => ref.read(onlineStatusProvider);

  Future<LocalRecipeStore?> _local() async {
    final uid = ref.read(recipeUserIdProvider);
    if (uid == null) return null;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return LocalRecipeStore(prefs, userId: uid);
  }

  @override
  Future<RecipesData> build() async {
    final remote = ref.watch(recipeRemoteStoreProvider);
    ref.watch(recipeUserIdProvider);
    final local = await _local();
    final now = _now();
    if (remote == null || local == null) return const RecipesData();

    if (AppConfig.useMock) await _seedMock(remote, now);

    // Recommendation cache: only readable online (generate needs it anyway);
    // offline the list stays empty and Favorites still work from the device.
    var recipes = <Recipe>[];
    if (_online) {
      try {
        final cached = await remote.fetchCache();
        recipes = pruneRecipeCache(cached, now: now);
        final kept = recipes.map((r) => r.recipeId).toSet();
        final evicted = [
          for (final r in cached)
            if (!kept.contains(r.recipeId)) r.recipeId,
        ];
        if (evicted.isNotEmpty) await remote.deleteCache(evicted);
      } on Object {
        recipes = const [];
      }
    }

    final favorites = await _loadFavorites(remote, local, now);
    return RecipesData(recipes: recipes, favorites: favorites);
  }

  Future<void> _seedMock(RecipeRemoteStore remote, DateTime now) async {
    if ((await remote.fetchCache()).isNotEmpty) return;
    final raw = jsonDecode(await ref.read(recipeFixtureLoaderProvider)());
    if (raw is! List) return;
    await remote.putCache([
      for (final e in raw)
        ?Recipe.tryParse(
          e is Map ? {...e, 'generatedAt': null, 'lastAccessedAt': null} : e,
          now: now,
        ),
    ]);
  }

  /// Online: server copy, mirrored to the device. Offline (or if the server
  /// is unreachable): the device snapshot (PRD §3.8).
  Future<List<FavoriteRecipe>> _loadFavorites(
    RecipeRemoteStore remote,
    LocalRecipeStore local,
    DateTime now,
  ) async {
    if (_online) {
      try {
        final fetched = _sortFavorites(await remote.fetchFavorites());
        await local.writeFavorites(fetched);
        return fetched;
      } on Object {
        // Fall back to the device snapshot below.
      }
    }
    return _sortFavorites(local.readFavorites(now: now));
  }

  static List<FavoriteRecipe> _sortFavorites(Iterable<FavoriteRecipe> f) =>
      [...f]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  RecipesData get _data => state.value ?? const RecipesData();

  /// Asks the AI for recipes using [ingredients] (already filtered by the
  /// caller, see [selectIngredients]). Returns the new recipes.
  ///
  /// Throws [RecipeActionException] when offline, signed out or over the
  /// client quota (10/hour, 30/day), and [AiException] for AI failures.
  Future<List<Recipe>> generate({
    required List<RecipeIngredient> ingredients,
    String? cuisine,
  }) async {
    if (!_online) throw const RecipeActionException(RecipeFailure.offline);
    final remote = _remote;
    final local = await _local();
    if (remote == null || local == null) {
      throw const RecipeActionException(RecipeFailure.signedOut);
    }
    if (ingredients.isEmpty) {
      throw const AiException(AiErrorCode.emptyIngredients);
    }

    final now = _now();
    final times = pruneRequestTimes(local.readGenerateTimes(), now: now);
    final quota = checkGenerateQuota(times, now: now);
    if (!quota.allowed) {
      throw RecipeActionException(
        RecipeFailure.quotaReached,
        retryAfter: quota.retryAfter,
      );
    }
    // Count the attempt up front: failed calls still use free-tier quota.
    await local.writeGenerateTimes([...times, now]);

    final fresh = await ref
        .read(recipeAiClientProvider)
        .generate(
          ingredients: ingredients,
          cuisine: cuisine,
          excludeRecipeIds: [for (final r in _data.recipes) r.recipeId],
        );

    // IDs become Firestore document ids and cache keys: replace any id that
    // is unsafe as a document id or already used, so a new result never
    // overwrites a cached or favorite recipe (older Workers let the AI pick
    // ids such as "r_001" on every call).
    final taken = {
      for (final r in _data.recipes) r.recipeId,
      for (final f in _data.favorites) f.favoriteId,
    };
    var seq = 0;
    String uniqueId(String id) {
      if (isSafeRecipeId(id) && taken.add(id)) return id;
      String next;
      do {
        next = 'r_${now.microsecondsSinceEpoch.toRadixString(36)}_${seq++}';
      } while (!taken.add(next));
      return next;
    }

    final stamped = [
      for (final r in fresh)
        Recipe(
          recipeId: uniqueId(r.recipeId),
          name: r.name,
          description: r.description,
          illustrationKey: r.illustrationKey,
          cuisine: r.cuisine,
          cookingTechnique: r.cookingTechnique,
          cookingTimeMinutes: r.cookingTimeMinutes,
          ingredientsAvailable: r.ingredientsAvailable,
          ingredientsMissing: r.ingredientsMissing,
          equipment: r.equipment,
          steps: r.steps,
          generatedAt: now,
          lastAccessedAt: now,
        ),
    ];

    final merged = {
      for (final r in _data.recipes) r.recipeId: r,
      for (final r in stamped) r.recipeId: r,
    }.values;
    final kept = pruneRecipeCache(merged, now: now);
    final keptIds = kept.map((r) => r.recipeId).toSet();

    final stampedIds = stamped.map((r) => r.recipeId).toSet();
    await remote.putCache(kept.where((r) => stampedIds.contains(r.recipeId)));
    final evicted = [
      for (final r in merged)
        if (!keptIds.contains(r.recipeId)) r.recipeId,
    ];
    if (evicted.isNotEmpty) await remote.deleteCache(evicted);

    state = AsyncData(_data.copyWith(recipes: kept));
    return [
      for (final r in stamped)
        if (keptIds.contains(r.recipeId)) r,
    ];
  }

  /// Marks a recipe as opened now so cache eviction keeps recent ones.
  Future<void> touch(String recipeId) async {
    final remote = _remote;
    final index = _data.recipes.indexWhere((r) => r.recipeId == recipeId);
    if (remote == null || index < 0) return;
    final touched = _data.recipes[index].copyWith(lastAccessedAt: _now());
    final recipes = [
      touched,
      for (var i = 0; i < _data.recipes.length; i++)
        if (i != index) _data.recipes[i],
    ];
    state = AsyncData(_data.copyWith(recipes: recipes));
    if (_online) {
      try {
        await remote.putCache([touched]);
      } on Object {
        // Best effort: the in-memory order is already updated.
      }
    }
  }

  /// Adds [recipe] to favorites with a full snapshot (PRD §3.8). Max 50.
  Future<void> addFavorite(Recipe recipe) async {
    if (!_online) throw const RecipeActionException(RecipeFailure.offline);
    final remote = _remote;
    final local = await _local();
    final uid = ref.read(recipeUserIdProvider);
    if (remote == null || local == null || uid == null) {
      throw const RecipeActionException(RecipeFailure.signedOut);
    }
    if (_data.isFavorite(recipe.recipeId)) return;
    if (_data.favorites.length >= RecipeLimits.favoritesMax) {
      throw const RecipeActionException(RecipeFailure.favoriteLimit);
    }
    final favorite = FavoriteRecipe(
      userId: uid,
      recipeSnapshot: recipe,
      savedAt: _now(),
    );
    await remote.putFavorite(favorite);
    final favorites = _sortFavorites([..._data.favorites, favorite]);
    await local.writeFavorites(favorites);
    state = AsyncData(_data.copyWith(favorites: favorites));
  }

  Future<void> removeFavorite(String recipeId) async {
    if (!_online) throw const RecipeActionException(RecipeFailure.offline);
    final remote = _remote;
    final local = await _local();
    if (remote == null || local == null) {
      throw const RecipeActionException(RecipeFailure.signedOut);
    }
    await remote.deleteFavorite(recipeId);
    final favorites = [
      for (final f in _data.favorites)
        if (f.favoriteId != recipeId) f,
    ];
    await local.writeFavorites(favorites);
    state = AsyncData(_data.copyWith(favorites: favorites));
  }

  /// Deletes a recipe everywhere: cache and favorites (PRD §3.5). The caller
  /// asks for confirmation first because this also removes the favorite.
  Future<void> deleteRecipe(String recipeId) async {
    if (!_online) throw const RecipeActionException(RecipeFailure.offline);
    final remote = _remote;
    final local = await _local();
    if (remote == null || local == null) {
      throw const RecipeActionException(RecipeFailure.signedOut);
    }
    await remote.deleteCache([recipeId]);
    await remote.deleteFavorite(recipeId);
    final favorites = [
      for (final f in _data.favorites)
        if (f.favoriteId != recipeId) f,
    ];
    await local.writeFavorites(favorites);
    state = AsyncData(
      _data.copyWith(
        recipes: [
          for (final r in _data.recipes)
            if (r.recipeId != recipeId) r,
        ],
        favorites: favorites,
      ),
    );
  }
}

final recipesControllerProvider =
    AsyncNotifierProvider<RecipesController, RecipesData>(
      RecipesController.new,
    );

/// Which recipe list the Recipe Finder shows.
enum RecipeTab { recommended, favorites }

class RecipeTabController extends Notifier<RecipeTab> {
  @override
  RecipeTab build() => RecipeTab.recommended;

  void select(RecipeTab tab) => state = tab;
}

final recipeTabProvider = NotifierProvider<RecipeTabController, RecipeTab>(
  RecipeTabController.new,
);

/// Filters of the Recipe Finder screen (PRD §3.5).
class RecipeFilter {
  const RecipeFilter({
    this.location = StorageLocation.fridge,
    this.cuisine,
    this.pickedFoodIds = const {},
  });

  final StorageLocation location;

  /// `null` = any cuisine.
  final String? cuisine;
  final Set<String> pickedFoodIds;

  RecipeFilter copyWith({
    StorageLocation? location,
    String? Function()? cuisine,
    Set<String>? pickedFoodIds,
  }) => RecipeFilter(
    location: location ?? this.location,
    cuisine: cuisine != null ? cuisine() : this.cuisine,
    pickedFoodIds: pickedFoodIds ?? this.pickedFoodIds,
  );
}

class RecipeFilterController extends Notifier<RecipeFilter> {
  @override
  RecipeFilter build() => const RecipeFilter();

  void setLocation(StorageLocation location) =>
      state = state.copyWith(location: location, pickedFoodIds: const {});

  void setCuisine(String? cuisine) =>
      state = state.copyWith(cuisine: () => cuisine);

  void togglePicked(String foodId) {
    final next = {...state.pickedFoodIds};
    if (!next.remove(foodId)) next.add(foodId);
    state = state.copyWith(pickedFoodIds: next);
  }
}

final recipeFilterProvider =
    NotifierProvider<RecipeFilterController, RecipeFilter>(
      RecipeFilterController.new,
    );

/// Pantry items the current filters would send to the AI. Reads the Pantry as
/// the single source of data (DevelopmentPlan, principle 6).
final recipeIngredientCandidatesProvider = Provider<AsyncValue<List<FoodItem>>>(
  (ref) {
    final filter = ref.watch(recipeFilterProvider);
    return ref
        .watch(pantryControllerProvider)
        .whenData(
          (items) => selectIngredients(items, location: filter.location),
        );
  },
);

/// User-facing copy for recipe errors. Never shows internal details.
String recipeErrorMessage(Object error) {
  if (error is RecipeActionException) {
    return switch (error.failure) {
      RecipeFailure.offline =>
        'You are offline. Generating recipes needs an internet connection.',
      RecipeFailure.quotaReached =>
        'You have reached the recipe limit for now. Open a saved recipe '
            'instead, or try again later.',
      RecipeFailure.favoriteLimit =>
        'You can save up to ${RecipeLimits.favoritesMax} favorite recipes. '
            'Remove one to add another.',
      RecipeFailure.signedOut => 'Please sign in again.',
    };
  }
  if (error is AiException) {
    return switch (error.code) {
      AiErrorCode.rateLimited =>
        'The recipe service is busy right now. Please try again in a moment.',
      AiErrorCode.timeout => 'Generating recipes took too long. Try again.',
      AiErrorCode.unauthorized =>
        'Your session has expired. Please sign in again.',
      AiErrorCode.network =>
        'Could not reach the server. Check your connection and try again.',
      AiErrorCode.emptyIngredients =>
        'Add food to your Pantry first, then generate recipes.',
      _ => 'Could not generate recipes. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
