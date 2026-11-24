import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/online_status.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/presentation/pantry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Reports whether each read asked for the device cache (PRD §7.5).
class _RecordingPantryRepository implements PantryRepository {
  _RecordingPantryRepository({
    List<FoodItem>? items,
    this.failure,
    this.alwaysFromCache = false,
  }) : items = items ?? const [];

  List<FoodItem> items;
  Object? failure;

  /// Simulates Firestore answering from its cache even though the device
  /// claims to be online.
  final bool alwaysFromCache;
  final List<bool> cacheCalls = [];

  @override
  Future<PantryRead> fetchAll({bool fromCache = false}) async {
    cacheCalls.add(fromCache);
    final error = failure;
    if (error != null) throw error;
    return PantryRead(items, fromCache: fromCache || alwaysFromCache);
  }

  @override
  Future<FoodItem> add(FoodDraft draft) => throw UnimplementedError();

  @override
  Future<FoodItem> update(FoodItem item) => throw UnimplementedError();

  @override
  Future<void> delete(String foodId) => throw UnimplementedError();
}

class _OfflineStatus extends OnlineStatus {
  @override
  bool build() => false;
}

FoodItem _item(String name) => FoodItem(
  foodId: name.toLowerCase(),
  userId: 'uid_1',
  name: name,
  category: 'Vegetables',
  quantity: 1,
  unit: 'pack',
  storageLocation: StorageLocation.fridge,
  purchaseDate: DateTime(2026, 11, 20),
  shelfLifeDays: 5,
  estimatedEndDate: DateTime(2026, 11, 25),
  visualCondition: null,
  aiNote: null,
  hasPhoto: false,
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

Widget _app(_RecordingPantryRepository repo, {bool online = true}) =>
    ProviderScope(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(repo),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        if (!online) onlineStatusProvider.overrideWith(_OfflineStatus.new),
      ],
      child: const MaterialApp(home: PantryScreen()),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offline reads the device cache and still lists items', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _RecordingPantryRepository(items: [_item('Spinach')]);
    await tester.pumpWidget(_app(repo, online: false));
    await _settle(tester);

    expect(repo.cacheCalls, [true]);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('offline with an empty cache shows the empty state, not an error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _RecordingPantryRepository();
    await tester.pumpWidget(_app(repo, online: false));
    await _settle(tester);

    expect(find.text('No food in Fridge yet'), findsOneWidget);
    expect(
      find.text('Adding food needs an internet connection.'),
      findsOneWidget,
    );
    expect(find.text('Could not load your pantry'), findsNothing);
    expect(find.text('Pantry is unavailable offline'), findsNothing);
  });

  testWidgets('reconnecting refreshes from the server, not the cache', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _RecordingPantryRepository(items: [_item('Spinach')]);
    await tester.pumpWidget(_app(repo, online: false));
    await _settle(tester);

    repo.items = [_item('Spinach'), _item('Carrot')];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PantryScreen)),
    );
    container.read(onlineStatusProvider.notifier).set(true);
    await _settle(tester);

    expect(repo.cacheCalls, [true, false]);
    expect(find.text('Carrot'), findsOneWidget);
    expect(find.textContaining('Synced'), findsOneWidget);
  });

  testWidgets('a cache read is never reported as freshly synced', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // The device claims to be online but Firestore served its cache, so the
    // data may be stale: report it as offline instead of "Synced just now".
    final repo = _RecordingPantryRepository(
      items: [_item('Spinach')],
      alwaysFromCache: true,
    );
    await tester.pumpWidget(_app(repo));
    await _settle(tester);

    expect(repo.cacheCalls, [false]);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining('Synced'), findsNothing);
  });

  testWidgets('an unreadable cache while offline explains the connection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _RecordingPantryRepository(
      failure: StateError('cache unavailable'),
    );
    await tester.pumpWidget(_app(repo, online: false));
    await _settle(tester);

    expect(find.text('Pantry is unavailable offline'), findsOneWidget);
    expect(find.text('Reconnect to load your ingredients.'), findsOneWidget);
  });
}
