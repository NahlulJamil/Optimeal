import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/models/food_item.dart';
import '../domain/shelf_life.dart';

/// Input for creating a new pantry item (from the scanner or manual add).
class FoodDraft {
  const FoodDraft({
    required this.name,
    required this.category,
    required this.storageLocation,
    required this.purchaseDate,
    required this.shelfLifeDays,
    this.quantity,
    this.unit,
    this.visualCondition,
    this.aiNote,
    this.hasPhoto = false,
  });

  final String name;
  final String category;
  final num? quantity;
  final String? unit;
  final StorageLocation storageLocation;
  final DateTime purchaseDate;
  final int shelfLifeDays;
  final String? visualCondition;
  final String? aiNote;
  final bool hasPhoto;
}

/// Source of truth for pantry data (DevelopmentPlan principle 6).
///
/// The Firestore implementation (`users/{uid}/pantry/{foodId}`) is owned by
/// Developer 1; until it exists the app uses [MockPantryRepository].
abstract class PantryRepository {
  Future<List<FoodItem>> fetchAll();
  Future<FoodItem> add(FoodDraft draft);
  Future<FoodItem> update(FoodItem item);
  Future<void> delete(String foodId);
}

/// In-memory repository seeded from `assets/fixtures/food_items.json`
/// (mock-first, DevelopmentPlan principle 3).
class MockPantryRepository implements PantryRepository {
  MockPantryRepository({
    Future<String> Function()? loadFixture,
    DateTime Function()? clock,
    this.userId = 'uid_demo',
  }) : _loadFixture =
           loadFixture ??
           (() => rootBundle.loadString('assets/fixtures/food_items.json')),
       _clock = clock ?? DateTime.now;

  final Future<String> Function() _loadFixture;
  final DateTime Function() _clock;
  final String userId;
  final Map<String, FoodItem> _items = {};
  bool _loaded = false;
  int _seq = 0;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = jsonDecode(await _loadFixture()) as List<Object?>;
    for (final e in raw) {
      final item = FoodItem.fromJson((e! as Map).cast<String, Object?>());
      _items[item.foodId] = item;
    }
    _loaded = true;
  }

  @override
  Future<List<FoodItem>> fetchAll() async {
    await _ensureLoaded();
    return List.unmodifiable(_items.values);
  }

  @override
  Future<FoodItem> add(FoodDraft draft) async {
    await _ensureLoaded();
    final now = _clock().toUtc();
    final id = 'f_${now.microsecondsSinceEpoch.toRadixString(36)}${_seq++}';
    final item = FoodItem(
      foodId: id,
      userId: userId,
      name: draft.name.trim(),
      category: draft.category,
      quantity: draft.quantity,
      unit: draft.unit,
      storageLocation: draft.storageLocation,
      purchaseDate: dateOnly(draft.purchaseDate),
      shelfLifeDays: draft.shelfLifeDays,
      estimatedEndDate: computeEstimatedEndDate(
        draft.purchaseDate,
        draft.shelfLifeDays,
      ),
      visualCondition: draft.visualCondition,
      aiNote: draft.aiNote,
      hasPhoto: draft.hasPhoto,
      createdAt: now,
      updatedAt: now,
    );
    _items[id] = item;
    return item;
  }

  @override
  Future<FoodItem> update(FoodItem item) async {
    await _ensureLoaded();
    if (!_items.containsKey(item.foodId)) {
      throw StateError('Food item ${item.foodId} not found');
    }
    // estimatedEndDate is always recomputed by the system.
    final updated = item.copyWith(
      estimatedEndDate: computeEstimatedEndDate(
        item.purchaseDate,
        item.shelfLifeDays,
      ),
      updatedAt: _clock().toUtc(),
    );
    _items[item.foodId] = updated;
    return updated;
  }

  @override
  Future<void> delete(String foodId) async {
    await _ensureLoaded();
    _items.remove(foodId);
  }
}
