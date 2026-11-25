import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/food_item.dart';
import '../../pantry/domain/shelf_life.dart';
import '../../pantry/presentation/food_form_entry.dart';
import '../data/ai_client.dart';
import '../data/image_prep.dart';

/// Firebase ID token for the Worker (`Authorization: Bearer …`).
///
/// Returns `null` when nobody is signed in; [HttpAiClient] then reports
/// `AiErrorCode.unauthorized` instead of sending a request that will 401.
/// Tests override this provider with a fixed token.
final idTokenSourceProvider = Provider<IdTokenSource>((ref) {
  return () async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    // `getIdToken()` refreshes transparently when the cached token expired.
    return user.getIdToken();
  };
});

final aiClientProvider = Provider<AiClient>((ref) {
  if (AppConfig.useMock) return MockAiClient();
  return HttpAiClient(
    baseUrl: AppConfig.aiProxyUrl,
    idToken: ref.watch(idTokenSourceProvider),
  );
});

final imagePreparerProvider = Provider<ImagePreparer>(
  (ref) => const ImagePreparer(),
);

/// Turns a validated AI result into an editable form entry. The user can
/// change every field before saving (PRD §3.3).
///
/// Scan Food defaults to Fridge (first option in the Figma dropdown). A
/// scanned package ([fromBarcode]) defaults to Pantry unless it is chilled
/// food, and its package size fills "Qty / Size".
FoodFormEntry entryFromAnalysis(
  FoodAnalysis analysis, {
  Uint8List? photo,
  DateTime? today,
  bool fromBarcode = false,
}) {
  final pkg = analysis.packageSize;
  final pkgValid = pkg != null && parseQuantity(pkg)?.quantity != null;
  return FoodFormEntry(
    name: analysis.name,
    category: analysis.category,
    location: fromBarcode
        ? defaultLocationForPackage(analysis.category)
        : StorageLocation.fridge,
    purchaseDate: dateOnly(today ?? DateTime.now()),
    estimate: analysis.shelfLife,
    quantityText: pkgValid ? pkg.trim() : '',
    visualCondition: analysis.visualCondition,
    aiNote: analysis.aiNote,
    confidence: analysis.confidence,
    photoBytes: photo,
  );
}

/// Packaged dairy, meat/seafood and fresh produce go to the fridge; other
/// packages (snacks, drinks, noodles, condiments…) to the Pantry shelf.
StorageLocation defaultLocationForPackage(String category) =>
    switch (normalizeCategory(category)) {
      'Dairy' ||
      'Meat & Seafood' ||
      'Vegetables' ||
      'Fruits' => StorageLocation.fridge,
      _ => StorageLocation.roomTemperature,
    };

/// User-facing copy for AI errors. Never shows internal details.
String aiErrorMessage(AiException e, {bool barcode = false}) =>
    switch (e.code) {
      AiErrorCode.rateLimited =>
        'Too many scans right now. Please wait a moment and try again.',
      AiErrorCode.timeout => 'The scan took too long. Please try again.',
      AiErrorCode.unauthorized =>
        'Your session has expired. Please sign in again.',
      AiErrorCode.network =>
        'Could not reach the server. Check your connection and try again.',
      AiErrorCode.invalidInput =>
        barcode
            ? 'This barcode could not be read. Try scanning it again.'
            : 'This photo could not be read. Try another one.',
      AiErrorCode.notFound => 'We could not recognize this product.',
      _ =>
        barcode
            ? 'Could not look up this product. Please try again.'
            : 'Could not analyze the food. Please try again.',
    };
