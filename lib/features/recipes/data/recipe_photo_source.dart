import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A photo found on Wikimedia Commons.
class PhotoCandidate {
  const PhotoCandidate({required this.imageUrl, required this.credit});

  final Uri imageUrl;

  /// Author and license, shown with the photo as the license asks.
  final String credit;
}

/// The lookup failed (network, rate limit, bad answer); it can be tried again.
class PhotoLookupException implements Exception {
  const PhotoLookupException(this.message);

  final String message;

  @override
  String toString() => 'PhotoLookupException: $message';
}

/// Search terms for a recipe photo, most specific first (PRD §6.3): the dish
/// name, its last two words, then the main ingredient.
///
/// Only these words are sent to Wikimedia. Punctuation is removed so that it
/// is not read as a search operator.
List<String> photoSearchTerms(String name, String ingredient) {
  List<String> words(String text) => text
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();

  final full = words(name);
  // "Spinach Pasta with Garlic" → the dish is "Spinach Pasta".
  final with_ = full.indexWhere((w) => w.toLowerCase() == 'with');
  final dish = with_ > 0 ? full.sublist(0, with_) : full;
  final main = words(ingredient);

  return {
    full.join(' '),
    dish.join(' '),
    if (dish.length > 2) dish.sublist(dish.length - 2).join(' '),
    if (main.isNotEmpty) '${main.join(' ')} food',
  }.where((term) => term.isNotEmpty).toList();
}

/// Free, key-less photo search on Wikimedia Commons (PRD §5.4, §6.3).
class WikimediaPhotoSource {
  WikimediaPhotoSource({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  /// Wikimedia asks every client to identify itself, ideally with a team
  /// contact (PRD §12.3 note 14). Add it here once the team has chosen one.
  static const userAgent = 'OptimealApp/1.0 (educational food app)';

  static const int maxImageBytes = 3 * 1024 * 1024;

  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _clock;
  DateTime? _blockedUntil;

  /// The best photo for [term], or `null` when Commons has none.
  Future<PhotoCandidate?> search(String term) async {
    final response = await _get(
      Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'formatversion': '2',
        'generator': 'search',
        'gsrnamespace': '6',
        'gsrsearch': '$term filetype:bitmap',
        'gsrlimit': '10',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|size|extmetadata',
        'iiextmetadatafilter': 'Artist|LicenseShortName',
        'iiurlwidth': '800',
      }),
    );
    try {
      return parsePhotoSearch(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const PhotoLookupException('Unreadable search answer');
    }
  }

  Future<Uint8List> download(Uri url) async {
    final response = await _get(url);
    final type = response.headers['content-type'] ?? '';
    final bytes = response.bodyBytes;
    if (!type.startsWith('image/') ||
        bytes.isEmpty ||
        bytes.length > maxImageBytes) {
      throw const PhotoLookupException('Not a usable image');
    }
    return bytes;
  }

  Future<http.Response> _get(Uri url) async {
    final blocked = _blockedUntil;
    if (blocked != null && _clock().isBefore(blocked)) {
      throw const PhotoLookupException('Waiting after a rate limit');
    }
    final http.Response response;
    try {
      response = await _client
          .get(url, headers: const {'User-Agent': userAgent})
          .timeout(timeout);
    } on TimeoutException {
      throw const PhotoLookupException('Timed out');
    } on http.ClientException catch (e) {
      throw PhotoLookupException(e.message);
    }
    if (response.statusCode == 429 || response.statusCode == 503) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      _blockedUntil = _clock().add(Duration(seconds: seconds ?? 60));
    }
    if (response.statusCode != 200) {
      throw PhotoLookupException('HTTP ${response.statusCode}');
    }
    return response;
  }
}

/// Thumbnails come from `thumb.`, originals (small photos) from `upload.`.
const _imageHosts = {'thumb.wikimedia.org', 'upload.wikimedia.org'};

/// Picks the first usable result of a Commons search: a JPEG (so no logos or
/// diagrams) whose license can be credited, preferring a landscape one.
PhotoCandidate? parsePhotoSearch(Object? json) {
  final query = json is Map ? json['query'] : null;
  final pages = query is Map ? query['pages'] : null;
  if (pages is! List) return null;

  final ranked = pages.whereType<Map<Object?, Object?>>().toList()
    ..sort(
      (a, b) =>
          ((a['index'] as num?) ?? 0).compareTo((b['index'] as num?) ?? 0),
    );

  PhotoCandidate? portrait;
  for (final page in ranked) {
    final infos = page['imageinfo'];
    if (infos is! List || infos.isEmpty) continue;
    final info = infos.first;
    if (info is! Map || info['mime'] != 'image/jpeg') continue;

    final url = Uri.tryParse('${info['thumburl'] ?? ''}');
    // Only Wikimedia's own image hosts are ever downloaded from.
    if (url == null ||
        url.scheme != 'https' ||
        !_imageHosts.contains(url.host)) {
      continue;
    }
    final credit = _credit(info['extmetadata']);
    if (credit == null) continue;

    final candidate = PhotoCandidate(imageUrl: url, credit: credit);
    final width = info['width'], height = info['height'];
    if (width is num && height is num && width < height) {
      portrait ??= candidate;
      continue;
    }
    return candidate;
  }
  return portrait;
}

/// `Photo: <author>, <license>, Wikimedia Commons`, or `null` when the license
/// needs an author and none is given.
String? _credit(Object? metadata) {
  String value(String key) {
    final entry = metadata is Map ? metadata[key] : null;
    final raw = entry is Map ? entry['value'] : null;
    return raw is String ? _plainText(raw) : '';
  }

  final license = value('LicenseShortName');
  if (license.isEmpty) return null;
  var author = value('Artist');
  final free = license.toLowerCase();
  if (author.isEmpty &&
      !free.contains('public domain') &&
      !free.contains('cc0')) {
    return null;
  }
  if (author.length > 60) author = '${author.substring(0, 60)}…';
  return [
    'Photo: ${author.isEmpty ? license : '$author, $license'}',
    'Wikimedia Commons',
  ].join(', ');
}

/// Commons returns the author as HTML.
String _plainText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
