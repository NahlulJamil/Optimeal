import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../../scanner/data/ai_client.dart' show AiErrorCode, AiException;
import 'recipe_image_client.dart';

/// Recipe images on the device (`<app documents>/recipe_images/`), so each one
/// is generated once and also shows offline (PRD §6.3, §6.7). Nothing goes to
/// Firestore.
class RecipeImageStore {
  RecipeImageStore({
    Future<Directory> Function()? baseDir,
    this.client,
    DateTime Function()? clock,
  }) : _baseDir = baseDir ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  /// How long nothing is generated after the quota ran out.
  static const pause = Duration(minutes: 10);

  /// `null` in mock mode: only saved images are shown.
  final RecipeImageClient? client;
  final Future<Directory> Function() _baseDir;
  final DateTime Function() _clock;

  /// Recipes whose generation failed; not repeated until the app restarts.
  final _failed = <String>{};
  DateTime? _pausedUntil;
  Future<void> _queue = Future.value();

  /// Bumped by [clear] so an image in progress is not written afterwards.
  int _generation = 0;

  /// The saved image, or a newly generated one when [online]. Returns `null`
  /// when there is none; an image is decoration, so this never throws.
  Future<File?> load(RecipeImageQuery query, {required bool online}) async {
    try {
      final key = query.recipeId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final dir = Directory('${(await _baseDir()).path}/recipe_images');
      final saved = File('${dir.path}/$key.jpg');
      if (await saved.exists()) return saved;
      final client = this.client;
      if (!online || client == null) return null;
      // One at a time, so a used-up quota stops the ones still waiting.
      final result = _queue.then((_) => _create(client, saved, key, query));
      _queue = result.then((_) {}, onError: (_) {});
      return await result;
    } on Object catch (error) {
      debugPrint('Recipe image unavailable: $error');
      return null;
    }
  }

  Future<File?> _create(
    RecipeImageClient client,
    File file,
    String key,
    RecipeImageQuery query,
  ) async {
    if (await file.exists()) return file;
    final paused = _pausedUntil;
    if (_failed.contains(key) ||
        (paused != null && _clock().isBefore(paused))) {
      return null;
    }
    final generation = _generation;
    final Uint8List bytes;
    try {
      bytes = await client.generate(query);
    } on AiException catch (e) {
      switch (e.code) {
        // Quota used up, or a Worker without this endpoint: asking for other
        // recipes would only fail too.
        case AiErrorCode.rateLimited || AiErrorCode.notFound:
          _pausedUntil = _clock().add(pause);
        // No quota was used, so it is free to try again.
        case AiErrorCode.network || AiErrorCode.unauthorized:
          break;
        // May have used quota.
        default:
          _failed.add(key);
      }
      rethrow;
    }
    if (generation != _generation) return null;
    await file.parent.create(recursive: true);
    // Renamed into place so a half-written image is never shown.
    final part = File('${file.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    return part.rename(file.path);
  }

  /// Removes every saved recipe image (logout, PRD §6.7), including photos
  /// kept by the earlier photo search.
  Future<void> clear() async {
    _generation++;
    _failed.clear();
    _pausedUntil = null;
    final base = (await _baseDir()).path;
    for (final name in const ['recipe_images', 'recipe_photos']) {
      final dir = Directory('$base/$name');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }
}
