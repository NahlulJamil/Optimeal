import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/features/recipes/application/recipe_providers.dart';
import 'package:optimeal/features/recipes/data/recipe_image_client.dart';
import 'package:optimeal/features/recipes/data/recipe_image_store.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';
import 'package:optimeal/features/recipes/presentation/widgets/recipe_illustration.dart';
import 'package:optimeal/features/recipes/presentation/widgets/recipe_picture.dart';
import 'package:optimeal/features/scanner/data/ai_client.dart';

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2];

class _FakeClient implements RecipeImageClient {
  /// Thrown instead of answering, when set.
  AiErrorCode? failure;
  final asked = <String>[];

  @override
  Future<Uint8List> generate(RecipeImageQuery query) async {
    asked.add(query.recipeId);
    final code = failure;
    if (code != null) throw AiException(code);
    return Uint8List.fromList(_jpeg);
  }
}

RecipeImageQuery _query([String id = 'r_1']) => (
  recipeId: id,
  name: 'Spinach Pasta',
  cuisine: 'Western',
  ingredients: 'Pasta, Spinach',
);

final _recipe = Recipe.tryParse({
  'recipeId': 'r_1',
  'name': 'Spinach Pasta',
  'description': 'Pasta.',
  'cuisine': 'Western',
  'cookingTechnique': 'Boil',
  'cookingTimeMinutes': 15,
  'ingredientsAvailable': ['150 g pasta', '100 g fresh spinach'],
  'ingredientsMissing': ['100 ml cooking cream'],
  'equipment': ['Pot'],
  'steps': ['Boil.'],
}, now: DateTime.utc(2026, 11, 27))!;

void main() {
  test('the image is drawn from names, without amounts', () {
    final query = imageQueryFor(_recipe);
    expect(query.name, 'Spinach Pasta');
    expect(query.ingredients, 'Pasta, Spinach, Cooking Cream');
  });

  group('HttpRecipeImageClient', () {
    HttpRecipeImageClient clientFor(
      Future<http.Response> Function(http.Request) handler,
    ) => HttpRecipeImageClient(
      baseUrl: 'https://worker.test',
      idToken: () async => 'token',
      client: MockClient(handler),
    );

    test('sends the recipe to the Worker and decodes the JPEG', () async {
      late http.Request sent;
      final client = clientFor((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'imageBase64': base64Encode(_jpeg),
            'mimeType': 'image/jpeg',
          }),
          200,
        );
      });

      expect(await client.generate(_query()), _jpeg);
      expect(sent.url.path, '/generate-recipe-image');
      expect(sent.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(sent.body), {
        'name': 'Spinach Pasta',
        'cuisine': 'Western',
        'ingredients': ['Pasta', 'Spinach'],
      });
    });

    test('reports a used-up quota and never retries', () async {
      var calls = 0;
      final client = clientFor((_) async {
        calls++;
        return http.Response('', 429);
      });

      await expectLater(
        client.generate(_query()),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.rateLimited,
          ),
        ),
      );
      expect(calls, 1);
    });

    test('rejects an answer that is not a JPEG', () {
      for (final body in [
        'oops',
        '{}',
        jsonEncode({'imageBase64': '***'}),
        jsonEncode({
          'imageBase64': base64Encode([1, 2, 3, 4]),
        }),
      ]) {
        expect(() => parseRecipeImage(body), throwsA(isA<AiException>()));
      }
    });
  });

  group('RecipeImageStore', () {
    late Directory dir;
    late _FakeClient client;
    var now = DateTime(2026, 11, 27, 9);

    setUp(() {
      dir = Directory.systemTemp.createTempSync('recipe_image');
      client = _FakeClient();
      now = DateTime(2026, 11, 27, 9);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    RecipeImageStore store({bool withClient = true}) => RecipeImageStore(
      baseDir: () async => dir,
      client: withClient ? client : null,
      clock: () => now,
    );

    test('generates once, then shows the saved image offline', () async {
      final image = await store().load(_query(), online: true);
      expect(image!.readAsBytesSync(), _jpeg);

      // A new store, as after restarting the app.
      expect(await store().load(_query(), online: false), isNotNull);
      expect(client.asked, ['r_1']);
    });

    test('two requests for one recipe generate one image', () async {
      final images = store();
      await Future.wait([
        images.load(_query(), online: true),
        images.load(_query(), online: true),
      ]);
      expect(client.asked, ['r_1']);
    });

    test('asks nothing while offline or in mock mode', () async {
      expect(await store().load(_query(), online: false), isNull);
      expect(await store(withClient: false).load(_query(), online: true), null);
      expect(client.asked, isEmpty);
    });

    test('a used-up quota pauses every recipe for a while', () async {
      final images = store();
      client.failure = AiErrorCode.rateLimited;
      expect(await images.load(_query(), online: true), isNull);
      expect(await images.load(_query('r_2'), online: true), isNull);
      expect(client.asked, ['r_1']);

      client.failure = null;
      now = now.add(RecipeImageStore.pause);
      expect(await images.load(_query('r_2'), online: true), isNotNull);
    });

    test('does not repeat a generation that may have used quota', () async {
      final images = store();
      client.failure = AiErrorCode.aiFailure;
      await images.load(_query(), online: true);
      client.failure = null;

      expect(await images.load(_query(), online: true), isNull);
      expect(await images.load(_query('r_2'), online: true), isNotNull);
      expect(client.asked, ['r_1', 'r_2']);
    });

    test('tries again after a network failure', () async {
      final images = store();
      client.failure = AiErrorCode.network;
      await images.load(_query(), online: true);
      client.failure = null;

      expect(await images.load(_query(), online: true), isNotNull);
    });

    test('clear removes saved images and old search photos', () async {
      final old = Directory('${dir.path}/recipe_photos')..createSync();
      final images = store();
      await images.load(_query(), online: true);
      await images.clear();

      expect(old.existsSync(), isFalse);
      expect(await images.load(_query(), online: false), isNull);
    });
  });

  group('RecipePicture', () {
    Future<void> pump(WidgetTester tester, File? image) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeImageProvider(imageQueryFor(_recipe))
                .overrideWith((ref) async => image),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                RecipePicture(recipe: _recipe),
                RecipeImageNote(recipe: _recipe),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the icon tile when there is no image', (tester) async {
      await pump(tester, null);
      expect(find.byType(RecipeIllustration), findsOneWidget);
      expect(find.text(RecipeImageNote.text), findsNothing);
    });

    testWidgets('labels the picture as made by AI', (tester) async {
      await pump(tester, File('missing.jpg'));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(RecipeImageNote.text), findsOneWidget);
    });
  });
}
