import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/presentation/food_form_entry.dart';
import 'package:optimeal/features/pantry/presentation/food_form_screen.dart';

import '../helpers/fakes.dart';

/// Fixture repository whose writes and reads can be made to fail.
class _FlakyRepository extends MockPantryRepository {
  /// Reads synchronously: real file I/O never completes inside `testWidgets`.
  _FlakyRepository()
    : super(
        loadFixture: () async =>
            File('assets/fixtures/food_items.json').readAsStringSync(),
      );

  /// Adding a food with this name fails.
  String? failingName;
  bool failReads = false;

  /// Names of every food written, in order.
  final added = <String>[];

  @override
  Future<FoodItem> add(FoodDraft draft) async {
    if (draft.name == failingName) throw StateError('write failed');
    final item = await super.add(draft);
    added.add(item.name);
    return item;
  }

  @override
  Future<PantryRead> fetchAll({bool fromCache = false}) {
    if (failReads) throw StateError('read failed');
    return super.fetchAll(fromCache: fromCache);
  }
}

class _FailingPhotoStore extends MemoryPhotoStore {
  @override
  Future<File> save(String foodId, Uint8List bytes) =>
      throw const FileSystemException('disk full');

  @override
  Future<void> delete(String foodId) =>
      throw const FileSystemException('no access');
}

FoodFormEntry _entry(String name) => FoodFormEntry(
  name: name,
  category: 'Vegetables',
  location: StorageLocation.fridge,
  purchaseDate: DateTime(2026, 11, 20),
);

FoodDraft _draft(String name) => _entry(name).toDraft();

void main() {
  late _FlakyRepository repo;

  setUp(() => repo = _FlakyRepository());

  ProviderContainer containerWith(MemoryPhotoStore photos) {
    final container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(repo),
        photoStoreProvider.overrideWithValue(photos),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Iterable<String> names(ProviderContainer c) =>
      c.read(pantryControllerProvider).value!.map((i) => i.name);

  test('a failed photo save does not fail an item already saved', () async {
    final container = containerWith(_FailingPhotoStore());
    await container.read(pantryControllerProvider.future);

    await container
        .read(pantryControllerProvider.notifier)
        .add(_draft('Pear'), photo: Uint8List.fromList([1]));

    expect(repo.added, ['Pear']);
    expect(names(container), contains('Pear'));
  });

  test('a failed re-read after a write still shows the change', () async {
    final container = containerWith(MemoryPhotoStore());
    final before = await container.read(pantryControllerProvider.future);
    final controller = container.read(pantryControllerProvider.notifier);
    repo.failReads = true;

    final added = await controller.add(_draft('Pear'));
    expect(names(container), contains('Pear'));

    await controller.edit(added.copyWith(name: 'Ripe Pear'));
    expect(names(container), contains('Ripe Pear'));
    expect(names(container), isNot(contains('Pear')));

    await controller.remove(added.foodId);
    expect(names(container), hasLength(before.length));
  });

  test('a failed photo delete does not fail a delete', () async {
    final container = containerWith(_FailingPhotoStore());
    await container.read(pantryControllerProvider.future);

    await container.read(pantryControllerProvider.notifier).remove('f_001');

    expect(
      container.read(pantryControllerProvider).value!.map((i) => i.foodId),
      isNot(contains('f_001')),
    );
  });

  Future<void> openForm(
    WidgetTester tester,
    List<FoodFormEntry> entries,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryRepositoryProvider.overrideWithValue(repo),
          photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // Keeps the pantry loaded behind the form, as the app does.
              ref.watch(pantryControllerProvider);
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FoodFormScreen.add(entries: entries),
                    ),
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAddFood(WidgetTester tester) async {
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();
  }

  testWidgets('retrying after a partial save adds each food once', (
    tester,
  ) async {
    final entries = [_entry('Pear'), _entry('Kale'), _entry('Leek')];
    repo.failingName = 'Kale';
    await openForm(tester, entries);

    await tapAddFood(tester);

    expect(repo.added, ['Pear']);
    // The saved food leaves the list (shared with the scanner).
    expect(entries.map((e) => e.name), ['Kale', 'Leek']);
    expect(
      find.text('1 of 3 foods saved. Could not save. Please try again.'),
      findsOneWidget,
    );

    repo.failingName = null;
    await tapAddFood(tester);

    expect(repo.added, ['Pear', 'Kale', 'Leek']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('foods saved earlier are not offered again', (tester) async {
    final entries = [_entry('Pear')..isSaved = true, _entry('Kale')];
    await openForm(tester, entries);

    expect(entries.map((e) => e.name), ['Kale']);
    await tapAddFood(tester);
    expect(repo.added, ['Kale']);
  });
}
