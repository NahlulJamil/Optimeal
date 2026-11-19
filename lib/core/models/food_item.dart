/// Data model shared by Pantry, Food Scanner and Smart Notification.
///
/// Mirrors `Docs/Contracts.md` §3.1 (`FoodItem`) and §3.6
/// (`ShelfLifeEstimate`). Do not add/rename fields without a contract change.
library;

/// Storage location enum. Data values are snake_case (Contracts §2.1); the UI
/// label is never translated.
enum StorageLocation {
  roomTemperature('room_temperature', 'Pantry'),
  fridge('fridge', 'Fridge'),
  freezer('freezer', 'Freezer');

  const StorageLocation(this.value, this.label);

  /// Value stored in Firestore / sent to the AI proxy.
  final String value;

  /// UI label (Pantry / Fridge / Freezer) on every language.
  final String label;

  static StorageLocation fromValue(String value) {
    return StorageLocation.values.firstWhere(
      (l) => l.value == value,
      orElse: () => throw FormatException('Unknown storageLocation: $value'),
    );
  }

  static StorageLocation? tryParse(String? value) {
    for (final l in StorageLocation.values) {
      if (l.value == value) return l;
    }
    return null;
  }
}

/// Shelf-life estimate for the three storage locations (Contracts §3.6).
class ShelfLifeEstimate {
  const ShelfLifeEstimate({
    required this.roomTemperature,
    required this.fridge,
    required this.freezer,
  });

  final int roomTemperature;
  final int fridge;
  final int freezer;

  int forLocation(StorageLocation location) => switch (location) {
    StorageLocation.roomTemperature => roomTemperature,
    StorageLocation.fridge => fridge,
    StorageLocation.freezer => freezer,
  };

  /// All three keys must be integers >= 1, otherwise `null` is returned so the
  /// caller can use the fallback catalog (Contracts §6.2).
  static ShelfLifeEstimate? tryParse(Object? json) {
    if (json is! Map) return null;
    int? read(String key) {
      final v = json[key];
      if (v is int && v >= 1) return v;
      if (v is double && v >= 1 && v == v.roundToDouble()) return v.toInt();
      return null;
    }

    final room = read('room_temperature');
    final fridge = read('fridge');
    final freezer = read('freezer');
    if (room == null || fridge == null || freezer == null) return null;
    return ShelfLifeEstimate(
      roomTemperature: room,
      fridge: fridge,
      freezer: freezer,
    );
  }

  Map<String, Object?> toJson() => {
    'room_temperature': roomTemperature,
    'fridge': fridge,
    'freezer': freezer,
  };
}

/// A food item stored in `users/{uid}/pantry/{foodId}`.
class FoodItem {
  const FoodItem({
    required this.foodId,
    required this.userId,
    required this.name,
    required this.category,
    required this.storageLocation,
    required this.purchaseDate,
    required this.shelfLifeDays,
    required this.estimatedEndDate,
    required this.hasPhoto,
    required this.createdAt,
    required this.updatedAt,
    this.quantity,
    this.unit,
    this.visualCondition,
    this.aiNote,
  });

  final String foodId;
  final String userId;
  final String name;
  final String category;
  final num? quantity;
  final String? unit;
  final StorageLocation storageLocation;
  final DateTime purchaseDate;
  final int shelfLifeDays;

  /// Always computed by the system: `purchaseDate + shelfLifeDays`.
  final DateTime estimatedEndDate;
  final String? visualCondition;
  final String? aiNote;
  final bool hasPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `quantity` without `unit` is invalid and shown as `—` (Contracts §3.1).
  String get quantityLabel {
    final q = quantity;
    final u = unit;
    if (q == null || u == null || u.trim().isEmpty) return '—';
    final qText = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    return '$qText $u';
  }

  FoodItem copyWith({
    String? name,
    String? category,
    num? Function()? quantity,
    String? Function()? unit,
    StorageLocation? storageLocation,
    DateTime? purchaseDate,
    int? shelfLifeDays,
    DateTime? estimatedEndDate,
    String? Function()? visualCondition,
    String? Function()? aiNote,
    bool? hasPhoto,
    DateTime? updatedAt,
  }) {
    return FoodItem(
      foodId: foodId,
      userId: userId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity != null ? quantity() : this.quantity,
      unit: unit != null ? unit() : this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
      estimatedEndDate: estimatedEndDate ?? this.estimatedEndDate,
      visualCondition: visualCondition != null
          ? visualCondition()
          : this.visualCondition,
      aiNote: aiNote != null ? aiNote() : this.aiNote,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FoodItem.fromJson(Map<String, Object?> json) {
    DateTime date(String key) => DateTime.parse(json[key]! as String);
    return FoodItem(
      foodId: json['foodId']! as String,
      userId: json['userId']! as String,
      name: json['name']! as String,
      category: json['category']! as String,
      quantity: json['quantity'] as num?,
      unit: json['unit'] as String?,
      storageLocation: StorageLocation.fromValue(
        json['storageLocation']! as String,
      ),
      purchaseDate: date('purchaseDate'),
      shelfLifeDays: (json['shelfLifeDays']! as num).toInt(),
      estimatedEndDate: date('estimatedEndDate'),
      visualCondition: json['visualCondition'] as String?,
      aiNote: json['aiNote'] as String?,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }

  /// Wire format (ISO-8601 UTC). Note: `estimatedEndDate` is included for
  /// reading back from storage; clients must never send a hand-made value.
  Map<String, Object?> toJson() => {
    'foodId': foodId,
    'userId': userId,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'storageLocation': storageLocation.value,
    'purchaseDate': purchaseDate.toUtc().toIso8601String(),
    'shelfLifeDays': shelfLifeDays,
    'estimatedEndDate': estimatedEndDate.toUtc().toIso8601String(),
    'visualCondition': visualCondition,
    'aiNote': aiNote,
    'hasPhoto': hasPhoto,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
