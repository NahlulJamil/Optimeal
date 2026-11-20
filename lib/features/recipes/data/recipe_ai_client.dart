import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../scanner/data/ai_client.dart'
    show AiErrorCode, AiException, IdTokenSource;
import '../domain/recipe.dart';
import '../domain/recipe_policy.dart';

/// `POST /generate-recipes` (Contracts §4.4). Calls go through the Cloudflare
/// Worker only (PRD §5.3); the Gemini key never reaches the app.
abstract class RecipeAiClient {
  Future<List<Recipe>> generate({
    required List<RecipeIngredient> ingredients,
    String? cuisine,
    List<String> excludeRecipeIds,
  });
}

/// Parses and validates the Worker response. Invalid recipes are dropped; if
/// none is usable the response is treated as a failure (PRD §5.3).
List<Recipe> parseGenerateResponse(Object? json, {required DateTime now}) {
  final raw = json is Map ? json['recipes'] : null;
  if (raw is! List) {
    throw const AiException(AiErrorCode.invalidResponse, 'No recipes list');
  }
  final recipes = <Recipe>[];
  final seen = <String>{};
  for (final entry in raw) {
    final recipe = Recipe.tryParse(entry, now: now);
    if (recipe != null && seen.add(recipe.recipeId)) recipes.add(recipe);
  }
  if (recipes.isEmpty) {
    throw const AiException(AiErrorCode.invalidResponse, 'No valid recipes');
  }
  return recipes;
}

class HttpRecipeAiClient implements RecipeAiClient {
  HttpRecipeAiClient({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
    this.timeout = AppConfig.aiTimeout,
    this.maxRetries = AppConfig.aiMaxRetries,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final String baseUrl;
  final IdTokenSource idToken;
  final http.Client _client;
  final Duration timeout;
  final int maxRetries;
  final DateTime Function() _clock;

  @override
  Future<List<Recipe>> generate({
    required List<RecipeIngredient> ingredients,
    String? cuisine,
    List<String> excludeRecipeIds = const [],
  }) async {
    if (ingredients.isEmpty) {
      throw const AiException(AiErrorCode.emptyIngredients);
    }
    final json = await _post({
      'ingredients': [for (final i in ingredients) i.toJson()],
      'filters': {'cuisine': cuisine},
      'excludeRecipeIds': excludeRecipeIds,
    });
    return parseGenerateResponse(json, now: _clock().toUtc());
  }

  /// Retries only 500 / 504, at most [maxRetries] times (Contracts §4.1).
  Future<Object?> _post(Map<String, Object?> body) async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const AiException(AiErrorCode.unauthorized, 'Not signed in');
    }
    final uri = Uri.parse(baseUrl).resolve('/generate-recipes');
    final encoded = jsonEncode(body);
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _client
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: encoded,
            )
            .timeout(timeout);
        if (response.statusCode == 200) {
          try {
            return jsonDecode(utf8.decode(response.bodyBytes));
          } on FormatException {
            throw const AiException(AiErrorCode.invalidResponse);
          }
        }
        throw AiException(
          AiException.codeForStatus(response.statusCode),
          _errorMessage(response),
        );
      } on TimeoutException {
        if (attempt >= maxRetries) {
          throw const AiException(AiErrorCode.timeout);
        }
      } on AiException catch (e) {
        if (!e.retryable || attempt >= maxRetries) rethrow;
      } on http.ClientException catch (e) {
        throw AiException(AiErrorCode.network, e.message);
      }
    }
  }

  static String? _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map && json['error'] is Map) {
        return (json['error'] as Map)['message'] as String?;
      }
    } on FormatException {
      // Non-JSON error body; the status code alone is enough.
    }
    return null;
  }
}

/// Mock mode (`USE_MOCK`): answers from `assets/fixtures/ai_responses.json`.
///
/// The same fixture recipe is returned on every call, so each generated id is
/// made unique to let the cache and favorites behave like real results.
class MockRecipeAiClient implements RecipeAiClient {
  MockRecipeAiClient({
    Future<String> Function()? loadFixture,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? clock,
  }) : _loadFixture =
           loadFixture ??
           (() => rootBundle.loadString('assets/fixtures/ai_responses.json')),
       _clock = clock ?? DateTime.now;

  final Future<String> Function() _loadFixture;
  final Duration latency;
  final DateTime Function() _clock;
  int _round = 0;

  @override
  Future<List<Recipe>> generate({
    required List<RecipeIngredient> ingredients,
    String? cuisine,
    List<String> excludeRecipeIds = const [],
  }) async {
    if (ingredients.isEmpty) {
      throw const AiException(AiErrorCode.emptyIngredients);
    }
    await Future<void>.delayed(latency);
    final fixture = jsonDecode(await _loadFixture()) as Map<String, Object?>;
    final parsed = parseGenerateResponse(
      fixture['generate-recipes'],
      now: _clock().toUtc(),
    );
    _round++;
    return [
      for (final r in parsed)
        Recipe(
          recipeId: '${r.recipeId}_m$_round',
          name: r.name,
          description: r.description,
          illustrationKey: r.illustrationKey,
          cuisine: cuisine ?? r.cuisine,
          cookingTechnique: r.cookingTechnique,
          cookingTimeMinutes: r.cookingTimeMinutes,
          ingredientsAvailable: r.ingredientsAvailable,
          ingredientsMissing: r.ingredientsMissing,
          equipment: r.equipment,
          steps: r.steps,
          generatedAt: r.generatedAt,
          lastAccessedAt: r.lastAccessedAt,
        ),
    ];
  }
}
