import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/connectivity/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatLastSynced', () {
    final now = DateTime.utc(2026, 11, 24, 12);

    test('describes recent and older timestamps', () {
      expect(
        formatLastSynced(now.subtract(const Duration(seconds: 20)), now: now),
        'just now',
      );
      expect(
        formatLastSynced(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        formatLastSynced(now.subtract(const Duration(hours: 2)), now: now),
        '2 h ago',
      );
      expect(
        formatLastSynced(now.subtract(const Duration(days: 3)), now: now),
        '3 d ago',
      );
    });
  });

  test('phase transitions update the state', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(syncStatusProvider.notifier);
    final at = DateTime.utc(2026, 11, 24, 10);

    controller.markSyncing();
    expect(container.read(syncStatusProvider).phase, SyncPhase.syncing);

    controller.markSynced(at);
    expect(container.read(syncStatusProvider).phase, SyncPhase.synced);
    expect(container.read(syncStatusProvider).lastSyncedAt, at);

    controller.markOffline();
    expect(container.read(syncStatusProvider).phase, SyncPhase.offline);
    expect(container.read(syncStatusProvider).lastSyncedAt, at);

    controller.markError();
    expect(container.read(syncStatusProvider).phase, SyncPhase.error);
  });

  test('restores the last sync time from storage', () async {
    final saved = DateTime.utc(2026, 11, 24, 9);
    SharedPreferences.setMockInitialValues({
      SyncStatusController.lastSyncedKey: saved.toIso8601String(),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(syncStatusProvider);
    await pumpEventQueue();

    expect(container.read(syncStatusProvider).lastSyncedAt, saved);
  });

  test('persists the last sync time', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final at = DateTime.utc(2026, 11, 24, 10);

    container.read(syncStatusProvider.notifier).markSynced(at);
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SyncStatusController.lastSyncedKey),
      at.toIso8601String(),
    );
  });

  test('clear removes the stored timestamp', () async {
    final saved = DateTime.utc(2026, 11, 24, 9);
    SharedPreferences.setMockInitialValues({
      SyncStatusController.lastSyncedKey: saved.toIso8601String(),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(syncStatusProvider.notifier).clear();

    expect(container.read(syncStatusProvider).lastSyncedAt, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SyncStatusController.lastSyncedKey), isNull);
  });
}
