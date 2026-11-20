import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optimeal/features/recipes/data/recipe_ai_client.dart';
import 'package:optimeal/features/recipes/domain/recipe_policy.dart';
import 'package:optimeal/features/scanner/data/ai_client.dart';

const _ingredient = RecipeIngredient(
  name: 'Spinach',
  quantity: 200,
  unit: 'g',
  storageLocation: 'fridge',
);

final _okBody = jsonEncode({
  'recipes': [
    {
      'recipeId': 'r_002',
      'name': 'Spinach Omelette',
      'description': 'Quick breakfast.',
      'cuisine': 'Western',
      'cookingTechnique': 'Pan-fry',
      'cookingTimeMinutes': 10,
      'ingredientsAvailable': ['200 g spinach'],
      'ingredientsMissing': ['Butter'],
      'equipment': ['Frying pan'],
      'steps': ['Beat the eggs.', 'Serve.'],
    },
    {'recipeId': 'broken'},
  ],
});

HttpRecipeAiClient _client(MockClient mock, {int retries = 2}) =>
    HttpRecipeAiClient(
      baseUrl: 'https://example.workers.dev',
      idToken: () async => 'token',
      client: mock,
      maxRetries: retries,
      clock: () => DateTime.utc(2026, 11, 20),
    );

Matcher _aiError(AiErrorCode code) =>
    isA<AiException>().having((e) => e.code, 'code', code);

void main() {
  test('posts the contract body with the bearer token', () async {
    late http.Request seen;
    final client = _client(
      MockClient((request) async {
        seen = request;
        return http.Response(_okBody, 200);
      }),
    );

    final recipes = await client.generate(
      ingredients: [_ingredient],
      cuisine: 'Western',
      excludeRecipeIds: ['r_001'],
    );

    expect(seen.url.path, '/generate-recipes');
    expect(seen.headers['Authorization'], 'Bearer token');
    final body = jsonDecode(seen.body) as Map<String, Object?>;
    expect(body['filters'], {'cuisine': 'Western'});
    expect(body['excludeRecipeIds'], ['r_001']);
    expect((body['ingredients']! as List).single, {
      'name': 'Spinach',
      'quantity': 200,
      'unit': 'g',
      'storageLocation': 'fridge',
    });
    // The malformed second recipe is dropped, not fatal.
    expect(recipes.map((r) => r.recipeId), ['r_002']);
  });

  test('cuisine null is sent as null (any cuisine)', () async {
    late http.Request seen;
    final client = _client(
      MockClient((request) async {
        seen = request;
        return http.Response(_okBody, 200);
      }),
    );
    await client.generate(ingredients: [_ingredient]);
    expect((jsonDecode(seen.body) as Map)['filters'], {'cuisine': null});
  });

  test('empty ingredients are refused without calling the Worker', () async {
    var called = false;
    final client = _client(
      MockClient((_) async {
        called = true;
        return http.Response(_okBody, 200);
      }),
    );
    await expectLater(
      client.generate(ingredients: const []),
      throwsA(_aiError(AiErrorCode.emptyIngredients)),
    );
    expect(called, isFalse);
  });

  test('429 is not retried', () async {
    var calls = 0;
    final client = _client(
      MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'code': 'RATE_LIMITED', 'message': 'quota'},
          }),
          429,
        );
      }),
    );
    await expectLater(
      client.generate(ingredients: [_ingredient]),
      throwsA(_aiError(AiErrorCode.rateLimited)),
    );
    expect(calls, 1);
  });

  test('500 is retried at most 2 times', () async {
    var calls = 0;
    final client = _client(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      client.generate(ingredients: [_ingredient]),
      throwsA(isA<AiException>()),
    );
    expect(calls, 3);
  });

  test('a response with no valid recipe is an invalid response', () async {
    final client = _client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'recipes': [
              {'recipeId': 'x'},
            ],
          }),
          200,
        ),
      ),
    );
    await expectLater(
      client.generate(ingredients: [_ingredient]),
      throwsA(_aiError(AiErrorCode.invalidResponse)),
    );
  });

  test('signed-out user gets unauthorized', () async {
    final client = HttpRecipeAiClient(
      baseUrl: 'https://example.workers.dev',
      idToken: () async => null,
      client: MockClient((_) async => http.Response(_okBody, 200)),
    );
    await expectLater(
      client.generate(ingredients: [_ingredient]),
      throwsA(_aiError(AiErrorCode.unauthorized)),
    );
  });
}
