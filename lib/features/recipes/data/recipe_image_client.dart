import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../scanner/data/ai_client.dart'
    show AiErrorCode, AiException, IdTokenSource;

/// What a recipe image is generated from. A record, so two copies of the same
/// recipe share one image. [ingredients] are names separated by `, `.
typedef RecipeImageQuery = ({
  String recipeId,
  String name,
  String cuisine,
  String ingredients,
});

/// `POST /generate-recipe-image` (Contracts §4.5): the Cloudflare Worker draws
/// the dish with Workers AI (PRD §6.3).
abstract class RecipeImageClient {
  /// JPEG bytes. Throws [AiException].
  Future<Uint8List> generate(RecipeImageQuery query);
}

class HttpRecipeImageClient implements RecipeImageClient {
  HttpRecipeImageClient({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
    this.timeout = AppConfig.aiTimeout,
  }) : _client = client ?? http.Client();

  static const int maxImageBytes = 3 * 1024 * 1024;

  final String baseUrl;
  final IdTokenSource idToken;
  final http.Client _client;
  final Duration timeout;

  /// Never retried: every attempt uses the shared daily quota (Contracts §4.5).
  @override
  Future<Uint8List> generate(RecipeImageQuery query) async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const AiException(AiErrorCode.unauthorized, 'Not signed in');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(baseUrl).resolve('/generate-recipe-image'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': query.name,
              'cuisine': query.cuisine,
              'ingredients': [
                if (query.ingredients.isNotEmpty)
                  ...query.ingredients.split(', '),
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiErrorCode.timeout);
    } on http.ClientException catch (e) {
      throw AiException(AiErrorCode.network, e.message);
    }
    if (response.statusCode != 200) {
      throw AiException(AiException.codeForStatus(response.statusCode));
    }
    return parseRecipeImage(response.body);
  }
}

/// Validates the Worker answer: a JPEG of a sensible size.
Uint8List parseRecipeImage(String body) {
  try {
    final json = jsonDecode(body);
    final encoded = json is Map ? json['imageBase64'] : null;
    if (encoded is String) {
      final bytes = base64Decode(encoded);
      if (bytes.length > 3 &&
          bytes.length <= HttpRecipeImageClient.maxImageBytes &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8) {
        return bytes;
      }
    }
  } on FormatException {
    // Reported below.
  }
  throw const AiException(AiErrorCode.invalidResponse, 'Not a usable image');
}
