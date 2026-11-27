import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/presentation/food_form_entry.dart';
import 'package:optimeal/features/pantry/presentation/food_form_screen.dart';

import '../helpers/fakes.dart';

class _RecordingRepository extends MockPantryRepository {
  /// Reads synchronously: real file I/O never completes inside `testWidgets`.
  _RecordingRepository()
    : super(
        loadFixture: () async =>
            File('assets/fixtures/food_items.json').readAsStringSync(),
      );

  final drafts = <FoodDraft>[];

  @override
  Future<FoodItem> add(FoodDraft draft) {
    drafts.add(draft);
    return super.add(draft);
  }
}

FoodFormEntry _scanned({String? condition, String? note}) => FoodFormEntry(
  name: 'Pear',
  category: 'Fruits',
  location: StorageLocation.fridge,
  purchaseDate: DateTime(2026, 11, 20),
  visualCondition: condition,
  aiNote: note,
);

void main() {
  late _RecordingRepository repo;

  setUp(() => repo = _RecordingRepository());

  Future<void> open(WidgetTester tester, FoodFormScreen form) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pantryRepositoryProvider.overrideWithValue(repo),
          photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => form)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder conditionField() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.hintText?.startsWith('e.g. Skin') ?? false),
  );

  testWidgets('shows what the scan saw and saves the correction', (
    tester,
  ) async {
    await open(
      tester,
      FoodFormScreen.add(
        entries: [_scanned(condition: 'Skin is green.', note: 'Eat soon.')],
      ),
    );

    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Skin is green.'), findsOneWidget);
    expect(find.text('AI note: Eat soon.'), findsOneWidget);

    await tester.ensureVisible(conditionField());
    await tester.pumpAndSettle();
    await tester.enterText(conditionField(), '  Small bruise on one side. ');
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    expect(repo.drafts.single.visualCondition, 'Small bruise on one side.');
    expect(repo.drafts.single.aiNote, 'Eat soon.');
  });

  testWidgets('each scanned food keeps its own condition', (tester) async {
    await open(
      tester,
      FoodFormScreen.add(
        entries: [
          _scanned(condition: 'First.'),
          _scanned(),
        ],
      ),
    );
    expect(find.text('First.'), findsOneWidget);

    // The second thumbnail has no scanned condition.
    await tester.tap(find.byIcon(Icons.restaurant).at(2));
    await tester.pumpAndSettle();
    expect(find.text('First.'), findsNothing);

    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();
    expect(repo.drafts.map((d) => d.visualCondition), ['First.', null]);
  });

  testWidgets('is not part of Edit food details', (tester) async {
    final item = (await repo.fetchAll()).items.first;
    await open(tester, FoodFormScreen.edit(item: item));

    expect(find.text('Shelf Life Estimate'), findsOneWidget);
    expect(find.text('Condition'), findsNothing);
  });
}
