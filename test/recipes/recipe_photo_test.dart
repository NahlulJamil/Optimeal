import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/features/recipes/application/recipe_providers.dart';
import 'package:optimeal/features/recipes/data/recipe_photo_source.dart';
import 'package:optimeal/features/recipes/data/recipe_photo_store.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';
import 'package:optimeal/features/recipes/presentation/widgets/recipe_illustration.dart';
import 'package:optimeal/features/recipes/presentation/widgets/recipe_picture.dart';

// The address shape Commons returns for thumbnails.
const _thumb = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/pasta.jpg';

Map<String, Object?> _page(
  int index, {
  String mime = 'image/jpeg',
  String url = _thumb,
  int width = 1200,
  int height = 800,
  String? artist = '<a href="x">Ana &amp; Budi</a>',
  String license = 'CC BY 2.0',
}) => {
  'index': index,
  'imageinfo': [
    {
      'mime': mime,
      'thumburl': url,
      'width': width,
      'height': height,
      'extmetadata': {
        if (artist != null) 'Artist': {'value': artist},
        'LicenseShortName': {'value': license},
      },
    },
  ],
};

Object _answer(List<Map<String, Object?>> pages) => {
  'query': {'pages': pages},
};

/// Commons stand-in: `found` is the only search term with a result.
class _Server {
  _Server({this.found = 'Spinach Pasta', this.status = 200});

  final String found;
  int status;
  final searches = <String>[];
  final userAgents = <String?>{};
  int downloads = 0;

  late final client = MockClient((request) async {
    userAgents.add(request.headers['User-Agent']);
    if (status != 200) {
      return http.Response('', status, headers: {'retry-after': '30'});
    }
    if (request.url.host == 'thumb.wikimedia.org') {
      downloads++;
      return http.Response.bytes(
        [1, 2, 3],
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    }
    final term = request.url.queryParameters['gsrsearch']!.replaceAll(
      ' filetype:bitmap',
      '',
    );
    searches.add(term);
    return http.Response(
      jsonEncode(term == found ? _answer([_page(1)]) : {'batchcomplete': true}),
      200,
    );
  });
}

void main() {
  group('photoSearchTerms', () {
    test('goes from the dish name to the main ingredient', () {
      expect(photoSearchTerms('Creamy Spinach Pasta with Garlic', 'Pasta'), [
        'Creamy Spinach Pasta with Garlic',
        'Creamy Spinach Pasta',
        'Spinach Pasta',
        'Pasta food',
      ]);
    });

    test('drops punctuation that would act as a search operator', () {
      expect(photoSearchTerms('"Mie" -Goreng: (spicy)', ''), ['Mie Goreng']);
    });
  });

  group('parsePhotoSearch', () {
    test('takes the best-ranked landscape JPEG with its credit', () {
      final photo = parsePhotoSearch(
        _answer([
          _page(3, url: 'https://upload.wikimedia.org/third.jpg'),
          _page(1, mime: 'image/png'),
          _page(2, width: 600, height: 900),
        ]),
      )!;
      expect('${photo.imageUrl}', 'https://upload.wikimedia.org/third.jpg');
      expect(photo.credit, 'Photo: Ana & Budi, CC BY 2.0, Wikimedia Commons');
    });

    test('skips other hosts and photos that cannot be credited', () {
      expect(
        parsePhotoSearch(
          _answer([
            _page(1, url: 'https://example.org/a.jpg'),
            _page(2, artist: null),
          ]),
        ),
        isNull,
      );
      expect(
        parsePhotoSearch(_answer([_page(1, artist: null, license: 'CC0')]))!
            .credit,
        'Photo: CC0, Wikimedia Commons',
      );
      expect(parsePhotoSearch({'batchcomplete': true}), isNull);
    });
  });

  group('RecipePhotoStore', () {
    const query = (
      recipeId: 'r_1',
      name: 'Spinach Pasta with Garlic',
      ingredient: 'Pasta',
    );
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('recipe_photo'));
    tearDown(() => dir.deleteSync(recursive: true));

    RecipePhotoStore storeFor(_Server server) => RecipePhotoStore(
      baseDir: () async => dir,
      source: WikimediaPhotoSource(client: server.client),
    );

    test('downloads once, then shows the saved photo offline', () async {
      final server = _Server();
      final photo = await storeFor(server).load(query, online: true);

      expect(photo!.file.readAsBytesSync(), [1, 2, 3]);
      expect(server.searches, ['Spinach Pasta with Garlic', 'Spinach Pasta']);
      expect(server.userAgents, {WikimediaPhotoSource.userAgent});

      // A new store, as after restarting the app.
      final offline = await storeFor(server).load(query, online: false);
      expect(offline!.credit, photo.credit);
      expect(server.downloads, 1);
    });

    test('asks nothing while offline', () async {
      final server = _Server();
      expect(await storeFor(server).load(query, online: false), isNull);
      expect(server.searches, isEmpty);
    });

    test('remembers that there is no photo', () async {
      final server = _Server(found: 'nothing');
      final store = storeFor(server);

      expect(await store.load(query, online: true), isNull);
      final asked = server.searches.length;
      expect(await store.load(query, online: true), isNull);
      expect(server.searches, hasLength(asked));
    });

    test('waits after a rate limit, and can try again later', () async {
      final server = _Server(status: 429);
      var now = DateTime(2026, 11, 27, 9);
      final store = RecipePhotoStore(
        baseDir: () async => dir,
        source: WikimediaPhotoSource(client: server.client, clock: () => now),
      );

      expect(await store.load(query, online: true), isNull);
      server.status = 200;
      expect(await store.load(query, online: true), isNull);
      expect(server.searches, isEmpty);

      now = now.add(const Duration(seconds: 31));
      expect(await store.load(query, online: true), isNotNull);
    });

    test('clear removes the saved photos', () async {
      final store = storeFor(_Server());
      await store.load(query, online: true);
      await store.clear();
      expect(await store.load(query, online: false), isNull);
    });
  });

  group('RecipePicture', () {
    final recipe = Recipe.tryParse({
      'recipeId': 'r_1',
      'name': 'Spinach Pasta',
      'description': 'Pasta.',
      'cuisine': 'Western',
      'cookingTechnique': 'Boil',
      'cookingTimeMinutes': 15,
      'ingredientsAvailable': ['150 g pasta'],
      'ingredientsMissing': <String>[],
      'equipment': ['Pot'],
      'steps': ['Boil.'],
    }, now: DateTime.utc(2026, 11, 27))!;

    Future<void> pump(WidgetTester tester, RecipePhoto? photo) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipePhotoProvider(photoQueryFor(recipe))
                .overrideWith((ref) async => photo),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                RecipePicture(recipe: recipe),
                RecipePhotoCredit(recipe: recipe),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the icon tile when there is no photo', (tester) async {
      await pump(tester, null);
      expect(find.byType(RecipeIllustration), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows the photo and its credit', (tester) async {
      await pump(
        tester,
        RecipePhoto(file: File('missing.jpg'), credit: 'Photo: Ana, CC0'),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo: Ana, CC0'), findsOneWidget);
    });
  });
}
