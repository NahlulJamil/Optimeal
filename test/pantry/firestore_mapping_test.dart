import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/data/firestore_pantry_repository.dart';

void main() {
  final item = FoodItem(
    foodId: 'f_1',
    userId: 'uid_1',
    name: 'Strawberries',
    category: 'Fruits',
    quantity: 1,
    unit: 'punnet',
    storageLocation: StorageLocation.fridge,
    purchaseDate: DateTime(2026, 11, 7),
    shelfLifeDays: 4,
    estimatedEndDate: DateTime(2026, 11, 11),
    visualCondition: 'Red',
    aiNote: null,
    hasPhoto: true,
    createdAt: DateTime.utc(2026, 11, 7, 3),
    updatedAt: DateTime.utc(2026, 11, 7, 3),
  );

  test('round-trips through the Firestore document format', () {
    final doc = foodItemToFirestore(item);
    expect(doc['storageLocation'], 'fridge');
    expect(doc['purchaseDate'], isA<Timestamp>());
    expect(doc['estimatedEndDate'], isA<Timestamp>());
    expect(doc.containsKey('imageUrl'), isFalse); // photos stay on device

    final back = foodItemFromFirestore('f_1', doc.cast<String, dynamic>())!;
    expect(back.name, 'Strawberries');
    expect(back.storageLocation, StorageLocation.fridge);
    expect(back.purchaseDate, DateTime(2026, 11, 7));
    expect(back.estimatedEndDate, DateTime(2026, 11, 11));
    expect(back.quantityLabel, '1 punnet');
    expect(back.hasPhoto, isTrue);
  });

  test('recomputes a missing estimatedEndDate', () {
    final doc = foodItemToFirestore(item)..remove('estimatedEndDate');
    final back = foodItemFromFirestore('f_1', doc.cast<String, dynamic>())!;
    expect(back.estimatedEndDate, DateTime(2026, 11, 11));
  });

  test('skips malformed documents instead of failing', () {
    final base = foodItemToFirestore(item).cast<String, dynamic>();
    expect(foodItemFromFirestore('x', {...base, 'name': ''}), isNull);
    expect(
      foodItemFromFirestore('x', {...base, 'storageLocation': 'Pantry'}),
      isNull,
    );
    expect(foodItemFromFirestore('x', {...base, 'shelfLifeDays': 0}), isNull);
    expect(
      foodItemFromFirestore('x', {...base}..remove('purchaseDate')),
      isNull,
    );
  });
}
