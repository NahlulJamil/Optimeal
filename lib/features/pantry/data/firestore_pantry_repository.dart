import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/food_item.dart';
import '../domain/shelf_life.dart';
import 'pantry_repository.dart';

/// Pantry stored in Firestore at `users/{uid}/pantry/{foodId}`
/// (PRD §6.6, Contracts §3.1). Dates are Firestore `Timestamp`s.
///
/// Reads use Firestore's offline persistence, so the list still loads from
/// the device cache when offline (PRD §7.5): [fetchAll] with `fromCache` reads
/// the local copy only, and a normal read falls back to it when the server is
/// unreachable. Writes are disabled in the UI while offline.
class FirestorePantryRepository implements PantryRepository {
  FirestorePantryRepository({
    required this.userId,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final String userId;
  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _pantry =>
      _db.collection('users').doc(userId).collection('pantry');

  @override
  Future<PantryRead> fetchAll({bool fromCache = false}) async {
    if (fromCache) return _read(Source.cache);
    try {
      return await _read(Source.serverAndCache);
    } on FirebaseException catch (error) {
      // The device is offline and the server read timed out; the cached copy
      // is the only source left (PRD §7.5).
      if (!_isOfflineError(error)) rethrow;
      return _read(Source.cache);
    }
  }

  Future<PantryRead> _read(Source source) async {
    final snapshot = await _pantry.get(GetOptions(source: source));
    final items = <FoodItem>[];
    for (final doc in snapshot.docs) {
      final item = foodItemFromFirestore(doc.id, doc.data());
      // A malformed document must not hide the rest of the pantry.
      if (item != null) items.add(item);
    }
    // `isFromCache` is Firestore's own answer, so the freshness line does not
    // depend on the connectivity plugin's guess (PRD §7.5).
    return PantryRead(items, fromCache: snapshot.metadata.isFromCache);
  }

  static bool _isOfflineError(FirebaseException error) =>
      error.code == 'unavailable' || error.code == 'deadline-exceeded';

  @override
  Future<FoodItem> add(FoodDraft draft) async {
    final ref = _pantry.doc();
    final now = _clock().toUtc();
    final item = FoodItem(
      foodId: ref.id,
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
    await ref.set(foodItemToFirestore(item));
    return item;
  }

  @override
  Future<FoodItem> update(FoodItem item) async {
    final updated = item.copyWith(
      estimatedEndDate: computeEstimatedEndDate(
        item.purchaseDate,
        item.shelfLifeDays,
      ),
      updatedAt: _clock().toUtc(),
    );
    final data = foodItemToFirestore(updated)..remove('createdAt');
    await _pantry.doc(item.foodId).update(data);
    return updated;
  }

  @override
  Future<void> delete(String foodId) => _pantry.doc(foodId).delete();
}

/// `FoodItem` → Firestore document (Contracts §3.1 field names).
Map<String, Object?> foodItemToFirestore(FoodItem item) => {
  'foodId': item.foodId,
  'userId': item.userId,
  'name': item.name,
  'category': item.category,
  'quantity': item.quantity,
  'unit': item.unit,
  'storageLocation': item.storageLocation.value,
  'purchaseDate': Timestamp.fromDate(item.purchaseDate),
  'shelfLifeDays': item.shelfLifeDays,
  'estimatedEndDate': Timestamp.fromDate(item.estimatedEndDate),
  'visualCondition': item.visualCondition,
  'aiNote': item.aiNote,
  'hasPhoto': item.hasPhoto,
  'createdAt': Timestamp.fromDate(item.createdAt),
  'updatedAt': Timestamp.fromDate(item.updatedAt),
};

/// Firestore document → `FoodItem`, or `null` when required fields are
/// missing or invalid. `estimatedEndDate` is recomputed if it is absent.
FoodItem? foodItemFromFirestore(String id, Map<String, dynamic> data) {
  DateTime? date(String key) {
    final v = data[key];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  final name = data['name'];
  final category = data['category'];
  final location = StorageLocation.tryParse(data['storageLocation'] as String?);
  final purchase = date('purchaseDate');
  final days = data['shelfLifeDays'];
  if (name is! String ||
      name.trim().isEmpty ||
      category is! String ||
      location == null ||
      purchase == null ||
      days is! num ||
      days < 1) {
    return null;
  }
  final created = date('createdAt') ?? purchase;
  return FoodItem(
    foodId: id,
    userId: data['userId'] as String? ?? '',
    name: name,
    category: category,
    quantity: data['quantity'] as num?,
    unit: data['unit'] as String?,
    storageLocation: location,
    purchaseDate: purchase,
    shelfLifeDays: days.toInt(),
    estimatedEndDate:
        date('estimatedEndDate') ??
        computeEstimatedEndDate(purchase, days.toInt()),
    visualCondition: data['visualCondition'] as String?,
    aiNote: data['aiNote'] as String?,
    hasPhoto: data['hasPhoto'] as bool? ?? false,
    createdAt: created,
    updatedAt: date('updatedAt') ?? created,
  );
}
