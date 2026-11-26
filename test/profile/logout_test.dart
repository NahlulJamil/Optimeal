import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/connectivity/sync_status.dart';
import 'package:optimeal/features/pantry/data/photo_store.dart';
import 'package:optimeal/features/profile/application/logout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePhotoStore extends PhotoStore {
  _FakePhotoStore({this.fails = false})
    : super(baseDir: () async => Directory.systemTemp);

  final bool fails;
  bool cleared = false;

  @override
  Future<void> clear() async {
    if (fails) throw const FileSystemException('no access');
    cleared = true;
  }
}

void main() {
  const uid = 'u1';

  Future<ProviderContainer> containerWithSession() async {
    SharedPreferences.setMockInitialValues({
      'recipes.favorites.$uid': '[]',
      'recipes.generateTimes.$uid': <String>[],
      SyncStatusController.lastSyncedKey: DateTime.utc(
        2026,
        11,
        25,
      ).toIso8601String(),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(syncStatusProvider.notifier).clear();
    container
        .read(syncStatusProvider.notifier)
        .markSynced(DateTime.utc(2026, 11, 25, 9));
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('clears photos, recipe data and the last sync time', () async {
    final container = await containerWithSession();
    final photos = _FakePhotoStore();

    await clearLocalSessionData(
      photos: photos,
      sync: container.read(syncStatusProvider.notifier),
      userId: uid,
    );

    expect(photos.cleared, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recipes.favorites.$uid'), isNull);
    expect(prefs.getStringList('recipes.generateTimes.$uid'), isNull);
    expect(prefs.getString(SyncStatusController.lastSyncedKey), isNull);
    expect(container.read(syncStatusProvider).lastSyncedAt, isNull);
  });

  test('a failing step does not stop the rest of the cleanup', () async {
    final container = await containerWithSession();
    final photos = _FakePhotoStore(fails: true);

    await clearLocalSessionData(
      photos: photos,
      sync: container.read(syncStatusProvider.notifier),
      userId: uid,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recipes.favorites.$uid'), isNull);
    expect(prefs.getString(SyncStatusController.lastSyncedKey), isNull);
  });
}
