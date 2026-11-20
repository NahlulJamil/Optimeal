import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/models/food_item.dart';

/// Error codes from Contracts §4.1.
enum AiErrorCode {
  invalidInput,
  unauthorized,
  notFound,
  emptyIngredients,
  rateLimited,
  aiFailure,
  timeout,
  network,
  invalidResponse,
}

class AiException implements Exception {
  const AiException(this.code, [this.message]);

  final AiErrorCode code;
  final String? message;

  /// Contracts §4.1: retry only 500 and 504.
  bool get retryable =>
      code == AiErrorCode.aiFailure || code == AiErrorCode.timeout;

  static AiErrorCode codeForStatus(int status) => switch (status) {
    400 => AiErrorCode.invalidInput,
    401 => AiErrorCode.unauthorized,
    404 => AiErrorCode.notFound,
    422 => AiErrorCode.emptyIngredients,
    429 => AiErrorCode.rateLimited,
    504 => AiErrorCode.timeout,
    _ => AiErrorCode.aiFailure,
  };

  @override
  String toString() => 'AiException($code, $message)';
}

/// Validated result of `POST /analyze-food` or `POST /analyze-barcode`.
class FoodAnalysis {
  const FoodAnalysis({
    required this.name,
    required this.category,
    required this.confidence,
    this.visualCondition,
    this.aiNote,
    this.shelfLife,
    this.brand,
    this.packageSize,
  });

  final String name;
  final String category;
  final double confidence;
  final String? visualCondition;
  final String? aiNote;

  /// `null` when the AI gave no valid estimate → use the fallback catalog.
  final ShelfLifeEstimate? shelfLife;

  /// Barcode only.
  final String? brand;
  final String? packageSize;

  /// Client-side validation of AI output (Contracts §6.1).
  static FoodAnalysis parse(Object? json) {
    if (json is! Map) {
      throw const AiException(AiErrorCode.invalidResponse, 'Not an object');
    }
    String? text(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final name = text('name');
    final category = text('category');
    final confidence = json['confidence'];
    if (name == null || category == null) {
      throw const AiException(
        AiErrorCode.invalidResponse,
        'Missing name or category',
      );
    }
    if (confidence is! num || confidence < 0 || confidence > 1) {
      throw const AiException(
        AiErrorCode.invalidResponse,
        'Confidence must be between 0 and 1',
      );
    }
    return FoodAnalysis(
      name: name,
      category: category,
      confidence: confidence.toDouble(),
      visualCondition: text('visualCondition'),
      aiNote: text('aiNote'),
      shelfLife: ShelfLifeEstimate.tryParse(json['shelfLifeDays']),
      brand: text('brand'),
      packageSize: text('packageSize'),
    );
  }
}

/// Calls to the AI go through the Cloudflare Worker only (PRD §5.3).
abstract class AiClient {
  Future<FoodAnalysis> analyzeFood(Uint8List jpegBytes, {String mimeType});
  Future<FoodAnalysis> analyzeBarcode(String barcode);
}

/// Supplies the Firebase ID token. Owned by Developer 1 (authentication).
typedef IdTokenSource = Future<String?> Function();

class HttpAiClient implements AiClient {
  HttpAiClient({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
    this.timeout = AppConfig.aiTimeout,
    this.maxRetries = AppConfig.aiMaxRetries,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final IdTokenSource idToken;
  final http.Client _client;
  final Duration timeout;
  final int maxRetries;

  @override
  Future<FoodAnalysis> analyzeFood(
    Uint8List jpegBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final json = await _post('/analyze-food', {
      'imageBase64': base64Encode(jpegBytes),
      'mimeType': mimeType,
    });
    return FoodAnalysis.parse(json);
  }

  @override
  Future<FoodAnalysis> analyzeBarcode(String barcode) async {
    final json = await _post('/analyze-barcode', {'barcode': barcode});
    return FoodAnalysis.parse(json);
  }

  Future<Object?> _post(String path, Map<String, Object?> body) async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const AiException(AiErrorCode.unauthorized, 'Not signed in');
    }
    final uri = Uri.parse(baseUrl).resolve(path);
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
      // Non-JSON error body; keep the status code only.
    }
    return null;
  }
}

/// Mock mode: answers from `assets/fixtures/ai_responses.json`.
class MockAiClient implements AiClient {
  MockAiClient({
    Future<String> Function()? loadFixture,
    this.unknownBarcodes = const {'0000000000000'},
    this.latency = const Duration(milliseconds: 600),
  }) : _loadFixture =
           loadFixture ??
           (() => rootBundle.loadString('assets/fixtures/ai_responses.json'));

  final Future<String> Function() _loadFixture;

  /// Barcodes that answer 404, to exercise the "not recognized" flow.
  final Set<String> unknownBarcodes;
  final Duration latency;

  Future<Object?> _fixture(String key) async {
    await Future<void>.delayed(latency);
    final json = jsonDecode(await _loadFixture()) as Map<String, Object?>;
    return json[key];
  }

  @override
  Future<FoodAnalysis> analyzeFood(
    Uint8List jpegBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (jpegBytes.isEmpty) throw const AiException(AiErrorCode.invalidInput);
    return FoodAnalysis.parse(await _fixture('analyze-food'));
  }

  @override
  Future<FoodAnalysis> analyzeBarcode(String barcode) async {
    if (barcode.trim().isEmpty) {
      throw const AiException(AiErrorCode.invalidInput);
    }
    if (unknownBarcodes.contains(barcode)) {
      await Future<void>.delayed(latency);
      throw const AiException(AiErrorCode.notFound);
    }
    return FoodAnalysis.parse(await _fixture('analyze-barcode'));
  }
}
