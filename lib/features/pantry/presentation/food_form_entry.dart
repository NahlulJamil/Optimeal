import 'dart:io';
import 'dart:typed_data';

import '../../../core/models/food_item.dart';
import '../data/pantry_repository.dart';
import '../domain/shelf_life.dart';

/// Editable state for one food in the "Food Details" form (Figma 355:94).
///
/// Used both for adding (one entry per scanned photo / barcode, or a manual
/// entry) and for "Edit food details" of a saved item.
class FoodFormEntry {
  FoodFormEntry({
    required this.name,
    required String category,
    required StorageLocation location,
    required this.purchaseDate,
    this.estimate,
    this.quantityText = '',
    this.visualCondition,
    this.aiNote,
    this.confidence,
    this.photoBytes,
    this.photoFile,
    int? shelfLifeDays,
    this.manualShelfLife = false,
  }) : category = normalizeCategory(category),
       _location = location {
    _shelfLifeDays =
        shelfLifeDays ??
        resolveShelfLifeDays(
          location: location,
          estimate: estimate,
          category: this.category,
        );
  }

  /// Entry for editing a saved item. The per-location AI estimate is not
  /// stored, so a location change falls back to the catalog (PRD §3.3 rule 3).
  factory FoodFormEntry.fromItem(FoodItem item, {File? photo}) {
    return FoodFormEntry(
      name: item.name,
      category: item.category,
      location: item.storageLocation,
      purchaseDate: item.purchaseDate,
      quantityText: item.quantityLabel == '—' ? '' : item.quantityLabel,
      visualCondition: item.visualCondition,
      aiNote: item.aiNote,
      photoFile: photo,
      shelfLifeDays: item.shelfLifeDays,
    );
  }

  String name;
  String category;
  DateTime purchaseDate;
  String quantityText;
  final ShelfLifeEstimate? estimate;
  final String? visualCondition;
  final String? aiNote;
  final double? confidence;
  final Uint8List? photoBytes;

  /// Saved local photo (edit mode). Locked: it cannot be replaced.
  File? photoFile;
  bool manualShelfLife;

  StorageLocation _location;
  late int _shelfLifeDays;

  bool get hasPhoto => photoBytes != null || photoFile != null;

  /// Below this the UI suggests correcting the name (PRD §3.3).
  bool get lowConfidence => confidence != null && confidence! < 0.6;

  StorageLocation get location => _location;

  /// Changing location re-selects the default estimate unless the user set
  /// the estimate manually (PRD §3.4).
  set location(StorageLocation value) {
    _location = value;
    if (!manualShelfLife) {
      _shelfLifeDays = resolveShelfLifeDays(
        location: value,
        estimate: estimate,
        category: category,
      );
    }
  }

  int get shelfLifeDays => _shelfLifeDays;

  DateTime get estimatedEndDate =>
      computeEstimatedEndDate(purchaseDate, _shelfLifeDays);

  /// User override, e.g. the date printed on the package (PRD §3.3 rule 6).
  void setEstimatedEndDate(DateTime endDate) {
    final days = calendarDaysBetween(purchaseDate, endDate);
    if (days < 1) {
      throw ArgumentError('The estimate must end after the purchase date.');
    }
    _shelfLifeDays = days;
    manualShelfLife = true;
  }

  /// Parsed "Qty / Size" (e.g. `1 bunch`, `500 g`). Empty is allowed.
  ({num? quantity, String? unit})? get parsedQuantity =>
      parseQuantity(quantityText);

  /// Returns an error message, or `null` when the entry can be saved.
  String? validate() {
    if (name.trim().isEmpty) return 'Food name is required.';
    if (!foodCategories.contains(category)) return 'Choose a category.';
    if (parsedQuantity == null) {
      return 'Write the quantity with a unit, e.g. "1 bunch" or "500 g".';
    }
    if (_shelfLifeDays < 1) return 'Shelf life must be at least 1 day.';
    return null;
  }

  FoodDraft toDraft() {
    final q = parsedQuantity!;
    return FoodDraft(
      name: name.trim(),
      category: category,
      quantity: q.quantity,
      unit: q.unit,
      storageLocation: _location,
      purchaseDate: dateOnly(purchaseDate),
      shelfLifeDays: _shelfLifeDays,
      visualCondition: visualCondition,
      aiNote: aiNote,
      hasPhoto: photoBytes != null,
    );
  }

  FoodItem applyTo(FoodItem item) {
    final q = parsedQuantity!;
    return item.copyWith(
      name: name.trim(),
      category: category,
      quantity: () => q.quantity,
      unit: () => q.unit,
      storageLocation: _location,
      purchaseDate: dateOnly(purchaseDate),
      shelfLifeDays: _shelfLifeDays,
      estimatedEndDate: estimatedEndDate,
    );
  }
}

final _quantityPattern = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$');

/// Parses "Qty / Size". Returns `(null, null)` for empty input and `null`
/// when invalid (a number without a unit is invalid — Contracts §3.1).
({num? quantity, String? unit})? parseQuantity(String text) {
  final t = text.trim();
  if (t.isEmpty) return (quantity: null, unit: null);
  final m = _quantityPattern.firstMatch(t);
  if (m == null) return null;
  final unit = m.group(2)!.trim();
  if (unit.isEmpty) return null;
  final quantity = num.parse(m.group(1)!.replaceAll(',', '.'));
  if (quantity <= 0) return null;
  return (quantity: quantity, unit: unit);
}
