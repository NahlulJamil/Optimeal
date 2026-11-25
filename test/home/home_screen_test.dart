import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/online_status.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/home/application/home_providers.dart';
import 'package:optimeal/features/home/presentation/home_screen.dart';
import 'package:optimeal/features/notification/application/notification_providers.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';

import '../helpers/fakes.dart';

final _recipe = Recipe(
  recipeId: 'r_002',
  name: 'Strawberry Smoothie',
  description: 'Perfect for breakfast or a hot day.',
  illustrationKey: 'recipe_western_drink',
  cuisine: 'Western',
  cookingTechnique: 'Blend',
  cookingTimeMinutes: 15,
  ingredientsAvailable: const ['Strawberry', 'Milk'],
  ingredientsMissing: const ['Honey'],
  equipment: const ['Blender'],
  steps: const ['Blend everything.'],
  generatedAt: DateTime.utc(2026, 11, 19),
  lastAccessedAt: DateTime.utc(2026, 11, 19),
);

final _yogurt = FoodItem(
  foodId: 'food_yogurt',
  userId: 'uid_demo',
  name: 'Greek Yogurt',
  category: 'Dairy',
  quantity: 500,
  unit: 'g',
  storageLocation: StorageLocation.fridge,
  purchaseDate: DateTime(2026, 11, 15),
  shelfLifeDays: 8,
  estimatedEndDate: DateTime(2026, 11, 23),
  hasPhoto: false,
  createdAt: DateTime(2026, 11, 15),
  updatedAt: DateTime(2026, 11, 15),
);

Widget _app({
  List overrides = const [],
  AsyncValue<Recipe?> recipe = const AsyncData(null),
  List<FoodItem> expiring = const [],
  VoidCallback? onOpenPantry,
  VoidCallback? onOpenRecipes,
  ValueChanged<String>? onOpenFood,
  ValueChanged<String>? onOpenRecipe,
}) => ProviderScope(
  overrides: [
    pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
    photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
    kitchenNameProvider.overrideWithValue("Sarah's Kitchen"),
    homeRecipeProvider.overrideWithValue(recipe),
    expiringSoonProvider.overrideWithValue(expiring),
    ...overrides.cast(),
  ],
  child: MaterialApp(
    home: HomeScreen(
      onOpenPantry: onOpenPantry,
      onOpenRecipes: onOpenRecipes,
      onOpenFood: onOpenFood,
      onOpenRecipe: onOpenRecipe,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Wait in real time until the fixture pantry has loaded; a fixed short
  // delay was flaky on slower machines (the spinner kept pumpAndSettle busy).
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!container.read(pantryControllerProvider).hasValue &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('shows greeting, summary, top pantry items and one recipe', (
    tester,
  ) async {
    await _pump(tester, _app(recipe: AsyncData(_recipe)));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text("Sarah's Kitchen"), findsOneWidget);

    // Summary counts: Pantry 1, Fridge 4, Freezer 0 from the fixture.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Pantry preview: the three closest estimates, not the rest.
    expect(find.text('Strawberries'), findsOneWidget);
    expect(find.text('Baby Spinach'), findsOneWidget);
    expect(find.text('Whole Milk'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);

    expect(find.text('AI Recipe Recommendations'), findsOneWidget);
    expect(find.text('Strawberry Smoothie'), findsOneWidget);
    expect(find.text('Perfect for breakfast or a hot day.'), findsOneWidget);
    expect(find.text('Strawberry'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('15 minute'), findsOneWidget);
  });

  testWidgets('recipe tags show the ingredient name, not the quantity', (
    tester,
  ) async {
    final pasta = Recipe(
      recipeId: 'r_pasta',
      name: 'Spinach Pasta',
      description: 'Creamy pasta with fresh spinach and garlic.',
      illustrationKey: 'recipe_italian',
      cuisine: 'Italian',
      cookingTechnique: 'Boil',
      cookingTimeMinutes: 15,
      ingredientsAvailable: const ['150 g pasta', '100 g fresh spinach'],
      ingredientsMissing: const ['Parmesan'],
      equipment: const ['Pot'],
      steps: const ['Boil the pasta.'],
      generatedAt: DateTime.utc(2026, 11, 19),
      lastAccessedAt: DateTime.utc(2026, 11, 19),
    );

    await _pump(tester, _app(recipe: AsyncData(pasta)));

    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.text('15 minute'), findsOneWidget);
    expect(find.textContaining('150 g'), findsNothing);
  });

  testWidgets('shows empty states when the pantry and recipes are empty', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        overrides: [
          pantrySummaryProvider.overrideWithValue(
            const AsyncData(HomeSummary.zero()),
          ),
          homePantryItemsProvider.overrideWithValue(
            const AsyncData(<FoodItem>[]),
          ),
        ],
      ),
    );

    expect(find.text('Your pantry is empty'), findsOneWidget);
    expect(find.text('No recipe recommendations yet'), findsOneWidget);
    expect(find.textContaining('expiring soon'), findsNothing);
  });

  testWidgets('shows loading and error states with a retry', (tester) async {
    await _pump(
      tester,
      _app(
        recipe: const AsyncLoading<Recipe?>(),
        overrides: [
          pantrySummaryProvider.overrideWithValue(
            const AsyncLoading<HomeSummary>(),
          ),
          homePantryItemsProvider.overrideWithValue(
            const AsyncLoading<List<FoodItem>>(),
          ),
        ],
      ),
      settle: false,
    );

    // Summary values are placeholders while the pantry loads.
    expect(find.text('–'), findsNWidgets(3));

    await _pump(
      tester,
      _app(
        recipe: AsyncError<Recipe?>(Exception('offline'), StackTrace.empty),
        overrides: [
          pantrySummaryProvider.overrideWithValue(
            AsyncError<HomeSummary>(Exception('offline'), StackTrace.empty),
          ),
          homePantryItemsProvider.overrideWithValue(
            AsyncError<List<FoodItem>>(Exception('offline'), StackTrace.empty),
          ),
        ],
      ),
    );

    expect(find.text('Could not load your pantry.'), findsOneWidget);
    expect(find.text('Could not load recipe recommendations.'), findsOneWidget);
    expect(find.text('Try again'), findsNWidgets(2));
  });

  testWidgets('banner counts expiring items and opens the reminders sheet', (
    tester,
  ) async {
    final opened = <String>[];
    await _pump(tester, _app(expiring: [_yogurt], onOpenFood: opened.add));

    expect(find.text('1 item expiring soon'), findsOneWidget);
    expect(find.text('Find recipes to use them up'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Greek Yogurt'), findsOneWidget);

    await tester.tap(find.text('Greek Yogurt'));
    await tester.pumpAndSettle();
    expect(opened, ['food_yogurt']);
  });

  testWidgets('shows the offline indicator and reports navigation taps', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      _app(
        recipe: AsyncData(_recipe),
        onOpenPantry: () => calls.add('pantry'),
        onOpenRecipes: () => calls.add('recipes'),
        onOpenRecipe: calls.add,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(onlineStatusProvider.notifier).set(false);
    await tester.pump();

    expect(find.text('Offline mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-pantry-view-all')));
    await tester.tap(find.byKey(const Key('home-recipes-view-all')));
    await tester.tap(find.text('Strawberry Smoothie'));
    await tester.pumpAndSettle();

    expect(calls, ['pantry', 'recipes', 'r_002']);
  });
}
