import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/recipe.dart';

/// Remote storage for recipes (PRD §6.6): the recommendation cache at
/// `users/{uid}/recipes/{recipeId}` and favorites at
/// `users/{uid}/favorites/{recipeId}`.
abstract class RecipeRemoteStore {
  Future<List<Recipe>> fetchCache();
  Future<void> putCache(Iterable<Recipe> recipes);
  Future<void> deleteCache(Iterable<String> recipeIds);

  Future<List<FavoriteRecipe>> fetchFavorites();
  Future<void> putFavorite(FavoriteRecipe favorite);
  Future<void> deleteFavorite(String recipeId);
}

/// In-memory store for mock mode (`USE_MOCK`) and tests.
class MemoryRecipeRemoteStore implements RecipeRemoteStore {
  MemoryRecipeRemoteStore({
    Iterable<Recipe> cache = const [],
    Iterable<FavoriteRecipe> favorites = const [],
  }) {
    for (final r in cache) {
      _cache[r.recipeId] = r;
    }
    for (final f in favorites) {
      _favorites[f.favoriteId] = f;
    }
  }

  final Map<String, Recipe> _cache = {};
  final Map<String, FavoriteRecipe> _favorites = {};

  @override
  Future<List<Recipe>> fetchCache() async => _cache.values.toList();

  @override
  Future<void> putCache(Iterable<Recipe> recipes) async {
    for (final r in recipes) {
      _cache[r.recipeId] = r;
    }
  }

  @override
  Future<void> deleteCache(Iterable<String> recipeIds) async {
    recipeIds.forEach(_cache.remove);
  }

  @override
  Future<List<FavoriteRecipe>> fetchFavorites() async =>
      _favorites.values.toList();

  @override
  Future<void> putFavorite(FavoriteRecipe favorite) async {
    _favorites[favorite.favoriteId] = favorite;
  }

  @override
  Future<void> deleteFavorite(String recipeId) async {
    _favorites.remove(recipeId);
  }
}

/// Firestore (Spark plan). Reads use Firestore's offline persistence.
class FirestoreRecipeRemoteStore implements RecipeRemoteStore {
  FirestoreRecipeRemoteStore({
    required this.userId,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final String userId;
  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(userId);
  CollectionReference<Map<String, dynamic>> get _recipes =>
      _user.collection('recipes');
  CollectionReference<Map<String, dynamic>> get _favorites =>
      _user.collection('favorites');

  @override
  Future<List<Recipe>> fetchCache() async {
    final snapshot = await _recipes.get();
    final now = _clock().toUtc();
    return [
      for (final doc in snapshot.docs)
        // A malformed document must not hide the rest of the list.
        ?Recipe.tryParse(_datesToIso(doc.data()), now: now),
    ];
  }

  @override
  Future<void> putCache(Iterable<Recipe> recipes) async {
    final batch = _db.batch();
    for (final r in recipes) {
      batch.set(_recipes.doc(r.recipeId), recipeToFirestore(r));
    }
    await batch.commit();
  }

  @override
  Future<void> deleteCache(Iterable<String> recipeIds) async {
    final batch = _db.batch();
    for (final id in recipeIds) {
      batch.delete(_recipes.doc(id));
    }
    await batch.commit();
  }

  @override
  Future<List<FavoriteRecipe>> fetchFavorites() async {
    final snapshot = await _favorites.get();
    final now = _clock().toUtc();
    return [
      for (final doc in snapshot.docs)
        ?FavoriteRecipe.tryParse(_favoriteDatesToIso(doc.data()), now: now),
    ];
  }

  @override
  Future<void> putFavorite(FavoriteRecipe favorite) =>
      _favorites.doc(favorite.favoriteId).set(favoriteToFirestore(favorite));

  @override
  Future<void> deleteFavorite(String recipeId) =>
      _favorites.doc(recipeId).delete();
}

/// `Recipe` → Firestore document: Contracts §3.2 names, `Timestamp` dates.
Map<String, Object?> recipeToFirestore(Recipe r) => {
  ...r.toJson(),
  'generatedAt': Timestamp.fromDate(r.generatedAt),
  'lastAccessedAt': Timestamp.fromDate(r.lastAccessedAt),
};

/// `FavoriteRecipe` → Firestore document (Contracts §3.3).
Map<String, Object?> favoriteToFirestore(FavoriteRecipe f) => {
  'favoriteId': f.favoriteId,
  'userId': f.userId,
  'recipeSnapshot': recipeToFirestore(f.recipeSnapshot),
  'savedAt': Timestamp.fromDate(f.savedAt),
};

Map<String, Object?> _datesToIso(Map<String, dynamic> data) {
  Object? iso(Object? v) =>
      v is Timestamp ? v.toDate().toUtc().toIso8601String() : v;
  return {
    ...data,
    'generatedAt': iso(data['generatedAt']),
    'lastAccessedAt': iso(data['lastAccessedAt']),
  };
}

Map<String, Object?> _favoriteDatesToIso(Map<String, dynamic> data) {
  final snapshot = data['recipeSnapshot'];
  return {
    ...data,
    'savedAt': data['savedAt'] is Timestamp
        ? (data['savedAt'] as Timestamp).toDate().toUtc().toIso8601String()
        : data['savedAt'],
    if (snapshot is Map<String, dynamic>)
      'recipeSnapshot': _datesToIso(snapshot),
  };
}

/// Device storage (PRD §6.7): full favorite snapshots so favorites open
/// offline, plus the generate-request timestamps for the client rate limit.
/// Keys include the user id so accounts never mix on one device; everything is
/// removed on logout with [clear].
class LocalRecipeStore {
  LocalRecipeStore(this._prefs, {required this.userId});

  final SharedPreferences _prefs;
  final String userId;

  String get _favoritesKey => 'recipes.favorites.$userId';
  String get _quotaKey => 'recipes.generateTimes.$userId';

  List<FavoriteRecipe> readFavorites({required DateTime now}) {
    final raw = _prefs.getString(_favoritesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final e in decoded) ?FavoriteRecipe.tryParse(e, now: now)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> writeFavorites(Iterable<FavoriteRecipe> favorites) =>
      _prefs.setString(
        _favoritesKey,
        jsonEncode([for (final f in favorites) f.toJson()]),
      );

  List<DateTime> readGenerateTimes() {
    final raw = _prefs.getStringList(_quotaKey) ?? const [];
    return [for (final s in raw) ?DateTime.tryParse(s)];
  }

  Future<void> writeGenerateTimes(Iterable<DateTime> times) =>
      _prefs.setStringList(_quotaKey, [
        for (final t in times) t.toUtc().toIso8601String(),
      ]);

  /// Called on logout so no recipe data stays for the next account.
  Future<void> clear() async {
    await _prefs.remove(_favoritesKey);
    await _prefs.remove(_quotaKey);
  }
}
