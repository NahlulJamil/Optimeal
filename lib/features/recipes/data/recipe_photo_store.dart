import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import 'recipe_photo_source.dart';

/// What the photo search needs from a recipe. A record, so two copies of the
/// same recipe share one lookup.
typedef RecipePhotoQuery = ({String recipeId, String name, String ingredient});

/// A photo saved on the device and the credit its license asks for.
class RecipePhoto {
  const RecipePhoto({required this.file, required this.credit});

  final File file;
  final String credit;
}

/// Recipe photos on the device (`<app documents>/recipe_photos/`), so a photo
/// loaded once also shows offline (PRD §6.3, §6.7). Nothing goes to Firestore.
class RecipePhotoStore {
  RecipePhotoStore({
    Future<Directory> Function()? baseDir,
    WikimediaPhotoSource? source,
  }) : _baseDir = baseDir ?? getApplicationDocumentsDirectory,
       _source = source ?? WikimediaPhotoSource();

  final Future<Directory> Function() _baseDir;
  final WikimediaPhotoSource _source;

  /// Recipes Commons had no photo for; not asked again until restart.
  final _notFound = <String>{};
  Future<void> _queue = Future.value();

  /// Bumped by [clear] so a download in progress is not written afterwards.
  int _generation = 0;

  /// The saved photo, or a newly downloaded one when [online]. Returns `null`
  /// when there is none; a photo is decoration, so this never throws.
  Future<RecipePhoto?> load(
    RecipePhotoQuery query, {
    required bool online,
  }) async {
    try {
      final key = query.recipeId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final dir = Directory('${(await _baseDir()).path}/recipe_photos');
      final saved = await _read(dir, key);
      if (saved != null || !online || _notFound.contains(key)) return saved;
      // One lookup at a time keeps within Wikimedia's request limits.
      final result = _queue.then((_) => _fetch(dir, key, query));
      _queue = result.then((_) {}, onError: (_) {});
      return await result;
    } on Object catch (error) {
      debugPrint('Recipe photo unavailable: $error');
      return null;
    }
  }

  Future<RecipePhoto?> _read(Directory dir, String key) async {
    final image = File('${dir.path}/$key.jpg');
    final credit = File('${dir.path}/$key.txt');
    if (!await image.exists() || !await credit.exists()) return null;
    return RecipePhoto(file: image, credit: await credit.readAsString());
  }

  Future<RecipePhoto?> _fetch(
    Directory dir,
    String key,
    RecipePhotoQuery query,
  ) async {
    final saved = await _read(dir, key);
    if (saved != null) return saved;
    final generation = _generation;
    for (final term in photoSearchTerms(query.name, query.ingredient)) {
      final candidate = await _source.search(term);
      if (candidate == null) continue;
      final bytes = await _source.download(candidate.imageUrl);
      if (generation != _generation) return null;
      await dir.create(recursive: true);
      await File('${dir.path}/$key.txt').writeAsString(candidate.credit);
      // Renamed into place so a half-written image is never shown.
      final part = File('${dir.path}/$key.part');
      await part.writeAsBytes(bytes, flush: true);
      final image = await part.rename('${dir.path}/$key.jpg');
      return RecipePhoto(file: image, credit: candidate.credit);
    }
    _notFound.add(key);
    return null;
  }

  /// Removes every saved recipe photo (logout, PRD §6.7).
  Future<void> clear() async {
    _generation++;
    _notFound.clear();
    final dir = Directory('${(await _baseDir()).path}/recipe_photos');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
