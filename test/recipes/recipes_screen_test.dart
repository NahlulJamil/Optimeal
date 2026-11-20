import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/online_status.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/recipes/application/recipe_providers.dart';
import 'package:optimeal/features/recipes/data/recipe_ai_client.dart';
import 'package:optimeal/features/recipes/presentation/recipes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Widget _app() => ProviderScope(
  overrides: [
    pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
    photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
    recipeFixtureLoaderProvider.overrideWithValue(
      () => File('assets/fixtures/recipes.json').readAsString(),
    ),
    recipeAiClientProvider.overrideWithValue(
      MockRecipeAiClient(
        latency: Duration.zero,
        loadFixture: () => File('assets/fixtures/ai_responses.json').readAsString(),
      ),
    ),
  ],
  child: const MaterialApp(home: RecipesScreen()),
);

Future<void> _pumpApp(WidgetTester tester, {Widget? app}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app ?? _app());
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the Figma filters and the cached recipes', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Search specific ingredients...'), findsOneWidget);
    expect(find.text('Generate recipes'), findsOneWidget);
    expect(find.text('Spinach Pasta'), findsOneWidget);
  });

  testWidgets('favorites tab is empty until a recipe is saved', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('No favorite recipes yet'), findsOneWidget);
    expect(find.text('Spinach Pasta'), findsNothing);
  });

  testWidgets('opens a recipe and switches detail tabs', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Spinach Pasta'));
    await tester.pumpAndSettle();

    expect(find.text('Cooking Time'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('150 g pasta'), findsOneWidget);

    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();
    expect(find.text('Cooking pot'), findsOneWidget);

    await tester.tap(find.text('Instructions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Boil the pasta'), findsOneWidget);
  });

  testWidgets('generate is disabled with an explanation while offline', (
    tester,
  ) async {
    final offlineApp = ProviderScope(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        recipeFixtureLoaderProvider.overrideWithValue(
          () => File('assets/fixtures/recipes.json').readAsString(),
        ),
        onlineStatusProvider.overrideWith(_OfflineStatus.new),
      ],
      child: const MaterialApp(home: RecipesScreen()),
    );
    await _pumpApp(tester, app: offlineApp);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate recipes'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('You are offline'), findsWidgets);
  });
}

class _OfflineStatus extends OnlineStatus {
  @override
  bool build() => false;
}
