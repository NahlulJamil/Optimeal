import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/connectivity/online_status.dart';
import 'package:optimeal/features/recipes/application/recipe_providers.dart';
import 'package:optimeal/features/recipes/data/recipe_ai_client.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';
import 'package:optimeal/features/recipes/domain/recipe_policy.dart';
import 'package:optimeal/features/scanner/data/ai_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns [perCall] fresh recipes on every call.
class _FakeAi implements RecipeAiClient {
  _FakeAi({this.perCall = 3, this.fixedIds});

  final int perCall;

  /// When set, every call returns these ids (like an AI that reuses ids).
  final List<String>? fixedIds;
  int calls = 0;
  AiException? failure;
  List<String> lastExcluded = const [];
  String? lastCuisine;

  @override
  Future<List<Recipe>> generate({
    required List<RecipeIngredient> ingredients,
    String? cuisine,
    List<String> excludeRecipeIds = const [],
  }) async {
    calls++;
    lastExcluded = excludeRecipeIds;
    lastCuisine = cuisine;
    final f = failure;
    if (f != null) throw f;
    final t = DateTime.utc(2000);
    return [
      for (var i = 0; i < perCall; i++)
        Recipe(
          recipeId: fixedIds?[i] ?? 'gen_${calls}_$i',
          name: 'Recipe $calls-$i',
          description: 'd',
          illustrationKey: 'recipe_western',
          cuisine: cuisine ?? 'Western',
          cookingTechnique: 'Saute',
          cookingTimeMinutes: 10,
          ingredientsAvailable: const ['1 spinach'],
          ingredientsMissing: const [],
          equipment: const ['Pan'],
          steps: const ['Cook.'],
          generatedAt: t,
          lastAccessedAt: t,
        ),
    ];
  }
}

const _ingredients = [
  RecipeIngredient(
    name: 'Spinach',
    quantity: null,
    unit: null,
    storageLocation: 'fridge',
  ),
];

void main() {
  late DateTime now;
  late _FakeAi ai;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        recipeAiClientProvider.overrideWithValue(ai),
        recipeClockProvider.overrideWithValue(() => now),
        recipeFixtureLoaderProvider.overrideWithValue(
          () => File('assets/fixtures/recipes.json').readAsString(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 20, 12);
    ai = _FakeAi();
  });

  Future<RecipesController> load(ProviderContainer c) async {
    await c.read(recipesControllerProvider.future);
    return c.read(recipesControllerProvider.notifier);
  }

  test('mock mode seeds the cache from the fixture file', () async {
    final c = makeContainer();
    final data = await c.read(recipesControllerProvider.future);
    expect(data.recipes.map((r) => r.recipeId), containsAll(['r_001']));
    expect(data.favorites, isEmpty);
  });

  test(
    'generate stores new recipes, excludes known ids, passes cuisine',
    () async {
      final c = makeContainer();
      final controller = await load(c);
      final before = c.read(recipesControllerProvider).value!.recipes;

      final fresh = await controller.generate(
        ingredients: _ingredients,
        cuisine: 'Japanese',
      );

      expect(fresh, hasLength(3));
      expect(ai.lastCuisine, 'Japanese');
      expect(ai.lastExcluded, before.map((r) => r.recipeId).toList());
      final data = c.read(recipesControllerProvider).value!;
      expect(data.recipes.map((r) => r.recipeId), containsAll(['gen_1_0']));
      // Server timestamps are replaced by the client clock.
      expect(
        data.recipes.firstWhere((r) => r.recipeId == 'gen_1_0').generatedAt,
        now,
      );
    },
  );

  test('cache never grows past 10 recipes', () async {
    ai = _FakeAi(perCall: 6);
    final c = makeContainer();
    final controller = await load(c);
    await controller.generate(ingredients: _ingredients);
    now = now.add(const Duration(minutes: 1));
    await controller.generate(ingredients: _ingredients);

    final recipes = c.read(recipesControllerProvider).value!.recipes;
    expect(recipes, hasLength(RecipeLimits.cacheMaxRecipes));
  });

  test(
    'the 11th request within an hour is refused before the Worker',
    () async {
      final c = makeContainer();
      final controller = await load(c);
      for (var i = 0; i < RecipeLimits.generatePerHour; i++) {
        now = now.add(const Duration(minutes: 1));
        await controller.generate(ingredients: _ingredients);
      }
      expect(ai.calls, RecipeLimits.generatePerHour);

      await expectLater(
        controller.generate(ingredients: _ingredients),
        throwsA(
          isA<RecipeActionException>().having(
            (e) => e.failure,
            'failure',
            RecipeFailure.quotaReached,
          ),
        ),
      );
      expect(ai.calls, RecipeLimits.generatePerHour);

      // An hour after the first request, generating works again.
      now = now.add(const Duration(hours: 1));
      await controller.generate(ingredients: _ingredients);
      expect(ai.calls, RecipeLimits.generatePerHour + 1);
    },
  );

  test('offline refuses generate and favorite changes', () async {
    final c = makeContainer();
    final controller = await load(c);
    c.read(onlineStatusProvider.notifier).set(false);

    Matcher offline() => throwsA(
      isA<RecipeActionException>().having(
        (e) => e.failure,
        'failure',
        RecipeFailure.offline,
      ),
    );
    await expectLater(
      controller.generate(ingredients: _ingredients),
      offline(),
    );
    final recipe = c.read(recipesControllerProvider).value!.recipes.first;
    await expectLater(controller.addFavorite(recipe), offline());
    await expectLater(controller.removeFavorite('x'), offline());
    await expectLater(controller.deleteRecipe('x'), offline());
    expect(ai.calls, 0);
  });

  test('AI failure surfaces and leaves the cache untouched', () async {
    final c = makeContainer();
    final controller = await load(c);
    final before = c.read(recipesControllerProvider).value!.recipes.length;
    ai.failure = const AiException(AiErrorCode.aiFailure);

    await expectLater(
      controller.generate(ingredients: _ingredients),
      throwsA(isA<AiException>()),
    );
    expect(c.read(recipesControllerProvider).value!.recipes, hasLength(before));
  });

  group('favorites', () {
    test('add and remove keep a full snapshot', () async {
      final c = makeContainer();
      final controller = await load(c);
      final recipe = c.read(recipesControllerProvider).value!.recipes.first;

      await controller.addFavorite(recipe);
      var data = c.read(recipesControllerProvider).value!;
      expect(data.isFavorite(recipe.recipeId), isTrue);
      expect(data.favorites.single.recipeSnapshot.steps, recipe.steps);
      expect(data.favorites.single.favoriteId, recipe.recipeId);

      await controller.removeFavorite(recipe.recipeId);
      data = c.read(recipesControllerProvider).value!;
      expect(data.isFavorite(recipe.recipeId), isFalse);
    });

    test('are capped at 50', () async {
      final c = makeContainer();
      final controller = await load(c);
      final base = c.read(recipesControllerProvider).value!.recipes.first;
      for (var i = 0; i < RecipeLimits.favoritesMax; i++) {
        await controller.addFavorite(
          Recipe(
            recipeId: 'fav_$i',
            name: base.name,
            description: base.description,
            illustrationKey: base.illustrationKey,
            cuisine: base.cuisine,
            cookingTechnique: base.cookingTechnique,
            cookingTimeMinutes: base.cookingTimeMinutes,
            ingredientsAvailable: base.ingredientsAvailable,
            ingredientsMissing: base.ingredientsMissing,
            equipment: base.equipment,
            steps: base.steps,
            generatedAt: base.generatedAt,
            lastAccessedAt: base.lastAccessedAt,
          ),
        );
      }
      await expectLater(
        controller.addFavorite(base),
        throwsA(
          isA<RecipeActionException>().having(
            (e) => e.failure,
            'failure',
            RecipeFailure.favoriteLimit,
          ),
        ),
      );
    });

    test('open offline from the device snapshot', () async {
      final first = makeContainer();
      final controller = await load(first);
      final recipe = first.read(recipesControllerProvider).value!.recipes.first;
      await controller.addFavorite(recipe);

      // New session, no connection: the remote store is empty (as if
      // unreachable) but SharedPreferences still holds the snapshot.
      final second = makeContainer();
      second.read(onlineStatusProvider.notifier).set(false);
      final data = await second.read(recipesControllerProvider.future);

      expect(data.favorites.map((f) => f.favoriteId), [recipe.recipeId]);
      expect(data.favorites.single.recipeSnapshot.name, recipe.name);
      // Cache is not read offline; favorites still are.
      expect(data.recipes, isEmpty);
    });
  });

  test('deleteRecipe removes it from cache and favorites', () async {
    final c = makeContainer();
    final controller = await load(c);
    final recipe = c.read(recipesControllerProvider).value!.recipes.first;
    await controller.addFavorite(recipe);

    await controller.deleteRecipe(recipe.recipeId);

    final data = c.read(recipesControllerProvider).value!;
    expect(data.recipes.any((r) => r.recipeId == recipe.recipeId), isFalse);
    expect(data.isFavorite(recipe.recipeId), isFalse);
    expect(data.find(recipe.recipeId), isNull);
  });

  test(
    'touch moves a recipe to the front and updates lastAccessedAt',
    () async {
      final c = makeContainer();
      final controller = await load(c);
      final recipes = c.read(recipesControllerProvider).value!.recipes;
      final last = recipes.last;

      now = now.add(const Duration(days: 1));
      await controller.touch(last.recipeId);

      final after = c.read(recipesControllerProvider).value!.recipes;
      expect(after.first.recipeId, last.recipeId);
      expect(after.first.lastAccessedAt, now);
    },
  );

  test('generate never overwrites cached recipes or uses unsafe ids', () async {
    ai = _FakeAi(perCall: 2, fixedIds: const ['r_001', 'bad/id']);
    final c = makeContainer();
    final controller = await load(c);
    final cached = c
        .read(recipesControllerProvider)
        .value!
        .recipes
        .firstWhere((r) => r.recipeId == 'r_001');

    final first = await controller.generate(ingredients: _ingredients);
    final second = await controller.generate(ingredients: _ingredients);

    final ids = [...first, ...second].map((r) => r.recipeId).toList();
    expect(ids.toSet(), hasLength(4));
    expect(ids, everyElement(isNot(anyOf('r_001', 'bad/id'))));
    expect(ids.every(isSafeRecipeId), isTrue);
    final data = c.read(recipesControllerProvider).value!;
    expect(data.find('r_001')?.name, cached.name);
  });
}
