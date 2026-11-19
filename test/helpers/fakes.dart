import 'dart:io';
import 'dart:typed_data';

import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/data/photo_store.dart';

/// Reads the real fixture file so tests use the same mock data as the app.
Future<String> loadFoodFixture() =>
    File('assets/fixtures/food_items.json').readAsString();

MockPantryRepository fixtureRepository({DateTime Function()? clock}) =>
    MockPantryRepository(loadFixture: loadFoodFixture, clock: clock);

/// Photo store that keeps photos in memory instead of the device.
class MemoryPhotoStore extends PhotoStore {
  MemoryPhotoStore() : super(baseDir: () async => Directory.systemTemp);

  final Map<String, Uint8List> saved = {};

  @override
  Future<File> save(String foodId, Uint8List bytes) async {
    saved[foodId] = bytes;
    return File('memory/$foodId.jpg');
  }

  @override
  Future<File?> find(String foodId) async => null;

  @override
  Future<void> delete(String foodId) async => saved.remove(foodId);

  @override
  Future<void> clear() async => saved.clear();
}
