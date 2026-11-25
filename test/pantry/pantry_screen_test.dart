import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/online_status.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/presentation/pantry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Widget _app({List overrides = const []}) => ProviderScope(
  overrides: [
    pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
    photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
    ...overrides.cast(),
  ],
  child: const MaterialApp(home: PantryScreen()),
);

/// Pumps the screen and waits (in real time) until the fixture pantry has
/// loaded. A fixed short delay was flaky on slower machines: the list was
/// still loading, so its spinner kept `pumpAndSettle` from settling.
Future<void> _pumpLoaded(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_app());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PantryScreen)),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!container.read(pantryControllerProvider).hasValue &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows fridge items, switches chips and searches', (
    tester,
  ) async {
    await _pumpLoaded(tester);

    expect(find.text('Pantry'), findsWidgets);
    expect(find.text('Strawberries'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);

    await tester.tap(find.text('Pantry').last);
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Strawberries'), findsNothing);

    await tester.tap(find.text('Fridge'));
    await tester.enterText(find.byType(TextField), 'spin');
    await tester.pumpAndSettle();
    expect(find.text('Baby Spinach'), findsOneWidget);
    expect(find.text('Whole Milk'), findsNothing);
  });

  testWidgets('detail screen disables editing while offline', (tester) async {
    late ProviderContainer container;
    await _pumpLoaded(tester);
    container = ProviderScope.containerOf(
      tester.element(find.byType(PantryScreen)),
    );
    container.read(onlineStatusProvider.notifier).set(false);

    await tester.tap(find.text('Strawberries'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Food'), findsOneWidget);
    expect(find.text('Estimated Shelf Life'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(offlineActionMessage), 200);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text(offlineActionMessage), findsOneWidget);
  });

  testWidgets('shows the last sync status and switches to offline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLoaded(tester);

    expect(find.textContaining('Synced'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PantryScreen)),
    );
    container.read(onlineStatusProvider.notifier).set(false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline · Last synced'), findsOneWidget);
  });
}
