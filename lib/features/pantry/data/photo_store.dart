import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Stores food photos on the device only (PRD §2.3 rule 10, §5.5).
///
/// Photos are never uploaded; only `hasPhoto` is stored in Firestore. The
/// `foodId → path` mapping is derived from the file name
/// (`<app documents>/food_photos/<foodId>.jpg`), so no extra database is needed.
class PhotoStore {
  PhotoStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  Directory? _dir;

  Future<Directory> _photosDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = Directory('${(await _baseDir()).path}/food_photos');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<File> _fileFor(String foodId) async =>
      File('${(await _photosDir()).path}/$foodId.jpg');

  /// Saves the (already compressed) thumbnail for [foodId].
  Future<File> save(String foodId, Uint8List bytes) async {
    final file = await _fileFor(foodId);
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Returns the local photo, or `null` when this device has none (for
  /// example after logging in on another device — PRD §12.3 note 1).
  Future<File?> find(String foodId) async {
    final file = await _fileFor(foodId);
    return file.existsSync() ? file : null;
  }

  Future<void> delete(String foodId) async {
    final file = await _fileFor(foodId);
    if (file.existsSync()) await file.delete();
  }

  /// Removes every local photo (called on logout by Developer 1).
  Future<void> clear() async {
    final dir = await _photosDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    _dir = null;
  }
}
