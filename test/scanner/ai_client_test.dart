import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/scanner/application/scanner_providers.dart';
import 'package:optimeal/features/scanner/data/ai_client.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  group('FoodAnalysis.parse (client-side validation)', () {
    test('accepts the contract example', () {
      final a = FoodAnalysis.parse({
        'name': 'Strawberries',
        'category': 'Fruit',
        'confidence': 0.93,
        'visualCondition': 'Red',
        'aiNote': null,
        'shelfLifeDays': {'room_temperature': 1, 'fridge': 4, 'freezer': 30},
      });
      expect(a.name, 'Strawberries');
      expect(a.shelfLife!.fridge, 4);
      expect(a.aiNote, isNull);
    });

    test('rejects empty name or bad confidence', () {
      expect(
        () =>
            FoodAnalysis.parse({'name': ' ', 'category': 'x', 'confidence': 1}),
        throwsA(isA<AiException>()),
      );
      expect(
        () => FoodAnalysis.parse({
          'name': 'a',
          'category': 'x',
          'confidence': 1.5,
        }),
        throwsA(isA<AiException>()),
      );
    });

    test('invalid shelf life becomes null so the catalog is used', () {
      final a = FoodAnalysis.parse({
        'name': 'Pear',
        'category': 'Fruit',
        'confidence': 0.4,
        'shelfLifeDays': {'room_temperature': -1, 'fridge': 4, 'freezer': 30},
      });
      expect(a.shelfLife, isNull);
      final entry = entryFromAnalysis(a, today: DateTime(2026, 11, 20));
      expect(entry.category, 'Fruits');
      expect(entry.lowConfidence, isTrue);
      expect(entry.location, StorageLocation.fridge);
      expect(entry.shelfLifeDays, 7); // fallback catalog, Fruits in fridge
    });
  });

  group('HttpAiClient', () {
    HttpAiClient client(MockClient http, {String? token = 'tok'}) =>
        HttpAiClient(
          baseUrl: 'https://worker.example',
          idToken: () async => token,
          client: http,
          timeout: const Duration(seconds: 2),
        );

    test('sends the token and base64 image to /analyze-food', () async {
      late http.Request sent;
      final c = client(
        MockClient((req) async {
          sent = req;
          return http.Response(
            jsonEncode({
              'name': 'Pear',
              'category': 'Fruit',
              'confidence': 0.9,
            }),
            200,
          );
        }),
      );
      final a = await c.analyzeFood(bytes);
      expect(a.name, 'Pear');
      expect(sent.url.path, '/analyze-food');
      expect(sent.headers['Authorization'], 'Bearer tok');
      final body = jsonDecode(sent.body) as Map;
      expect(body['imageBase64'], base64Encode(bytes));
      expect(body['mimeType'], 'image/jpeg');
    });

    test('retries 500 at most twice, then fails', () async {
      var calls = 0;
      final c = client(
        MockClient((req) async {
          calls++;
          return http.Response('{"error":{"code":"AI_FAILURE"}}', 500);
        }),
      );
      await expectLater(
        c.analyzeBarcode('123'),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.aiFailure,
          ),
        ),
      );
      expect(calls, 3);
    });

    test('does not retry 404 or 429', () async {
      for (final status in [404, 429]) {
        var calls = 0;
        final c = client(
          MockClient((req) async {
            calls++;
            return http.Response('{}', status);
          }),
        );
        await expectLater(c.analyzeBarcode('123'), throwsA(isA<AiException>()));
        expect(calls, 1, reason: 'status $status');
      }
    });

    test('refuses to call without a signed-in user', () async {
      final c = client(
        MockClient((req) async => fail('should not be called')),
        token: null,
      );
      await expectLater(
        c.analyzeFood(bytes),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.unauthorized,
          ),
        ),
      );
    });
  });

  group('MockAiClient', () {
    final mock = MockAiClient(
      loadFixture: () =>
          File('assets/fixtures/ai_responses.json').readAsString(),
      latency: Duration.zero,
    );

    test('answers from the fixture', () async {
      expect((await mock.analyzeFood(bytes)).name, 'Strawberries');
      final barcode = await mock.analyzeBarcode('8991234567890');
      expect(barcode.name, 'Greek Yogurt');
      expect(entryFromAnalysis(barcode).quantityText, '500 g');
    });

    test('unknown barcode answers NOT_FOUND', () async {
      await expectLater(
        mock.analyzeBarcode('0000000000000'),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.notFound,
          ),
        ),
      );
    });
  });
}
