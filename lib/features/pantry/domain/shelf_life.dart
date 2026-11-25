import '../../../core/models/food_item.dart';

/// Shelf-life rules from PRD §3.3 ("Aturan estimasi masa simpan") and §3.4.
///
/// Dates are handled as calendar days in the device's local time zone.

/// Food categories, in the order of the Figma category dropdown.
const List<String> foodCategories = [
  'Vegetables',
  'Fruits',
  'Meat & Seafood',
  'Dairy',
  'Grains & Cereals',
  'Snacks & Beverages',
  'Condiments & Spices',
  'Others',
];

/// Maps AI / legacy category strings (e.g. `Fruit`, `Vegetable`) to the
/// category list above. Unknown values become `Others`.
String normalizeCategory(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return 'Others';
  for (final c in foodCategories) {
    if (c.toLowerCase() == v) return c;
  }
  const aliases = {
    'vegetable': 'Vegetables',
    'veggie': 'Vegetables',
    'sayur': 'Vegetables',
    'fruit': 'Fruits',
    'buah': 'Fruits',
    'meat': 'Meat & Seafood',
    'seafood': 'Meat & Seafood',
    'fish': 'Meat & Seafood',
    'poultry': 'Meat & Seafood',
    'daging': 'Meat & Seafood',
    'egg': 'Dairy',
    'eggs': 'Dairy',
    'milk': 'Dairy',
    'grain': 'Grains & Cereals',
    'grains': 'Grains & Cereals',
    'cereal': 'Grains & Cereals',
    'carbohydrate': 'Grains & Cereals',
    'karbohidrat': 'Grains & Cereals',
    'snack': 'Snacks & Beverages',
    'snacks': 'Snacks & Beverages',
    'beverage': 'Snacks & Beverages',
    'beverages': 'Snacks & Beverages',
    'drink': 'Snacks & Beverages',
    'condiment': 'Condiments & Spices',
    'condiments': 'Condiments & Spices',
    'spice': 'Condiments & Spices',
    'spices': 'Condiments & Spices',
    'bumbu': 'Condiments & Spices',
    'sauce': 'Condiments & Spices',
    'seasoning': 'Condiments & Spices',
    'noodle': 'Grains & Cereals',
    'noodles': 'Grains & Cereals',
    'rice': 'Grains & Cereals',
    'bread': 'Grains & Cereals',
    'pasta': 'Grains & Cereals',
    'tea': 'Snacks & Beverages',
    'coffee': 'Snacks & Beverages',
    'juice': 'Snacks & Beverages',
    'other': 'Others',
  };
  return aliases[v] ?? 'Others';
}

/// Fallback catalog used when the AI does not return a valid estimate
/// (PRD §3.3 rule 3). Mirrors `foodCatalog/{category}`; Developer 1 may later
/// load the same values from Firestore.
const Map<String, ShelfLifeEstimate> fallbackShelfLifeCatalog = {
  'Vegetables': ShelfLifeEstimate(roomTemperature: 2, fridge: 5, freezer: 240),
  'Fruits': ShelfLifeEstimate(roomTemperature: 3, fridge: 7, freezer: 240),
  'Meat & Seafood': ShelfLifeEstimate(
    roomTemperature: 1,
    fridge: 2,
    freezer: 90,
  ),
  'Dairy': ShelfLifeEstimate(roomTemperature: 1, fridge: 7, freezer: 60),
  'Grains & Cereals': ShelfLifeEstimate(
    roomTemperature: 180,
    fridge: 180,
    freezer: 365,
  ),
  'Snacks & Beverages': ShelfLifeEstimate(
    roomTemperature: 90,
    fridge: 120,
    freezer: 180,
  ),
  'Condiments & Spices': ShelfLifeEstimate(
    roomTemperature: 180,
    fridge: 365,
    freezer: 365,
  ),
  'Others': ShelfLifeEstimate(roomTemperature: 3, fridge: 7, freezer: 30),
};

ShelfLifeEstimate fallbackEstimateFor(String category) =>
    fallbackShelfLifeCatalog[normalizeCategory(category)] ??
    fallbackShelfLifeCatalog['Others']!;

/// Local calendar date at 00:00.
DateTime dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// `purchaseDate + shelfLifeDays`. Quantity never affects this (PRD §3.3 rule 5).
DateTime computeEstimatedEndDate(DateTime purchaseDate, int shelfLifeDays) {
  final p = dateOnly(purchaseDate);
  return DateTime(p.year, p.month, p.day + shelfLifeDays);
}

/// Number of whole days between two dates, as calendar days.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  // Use UTC to avoid DST off-by-one errors.
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Days left until the shelf-life estimate ends. 0 = today, negative = past.
int daysLeft(FoodItem item, {DateTime? now}) =>
    calendarDaysBetween(now ?? DateTime.now(), item.estimatedEndDate);

/// Visual urgency used by the "days left" badge in the Figma list rows.
enum ShelfUrgency { today, soon, fresh }

ShelfUrgency urgencyFor(int daysLeft) {
  if (daysLeft <= 0) return ShelfUrgency.today;
  if (daysLeft <= 3) return ShelfUrgency.soon;
  return ShelfUrgency.fresh;
}

/// Badge copy. Uses "days left" wording, never "spoiled"/"rotten"
/// (PRD §3.6 rule 6).
String daysLeftLabel(int daysLeft) {
  if (daysLeft < 0) return 'Past estimate';
  if (daysLeft == 0) return 'Use Today';
  if (daysLeft == 1) return '1 day left';
  return '$daysLeft days left';
}

/// Applies an edit and recomputes derived fields (PRD §3.4):
/// * location change re-selects the default estimate unless the user set the
///   estimate manually;
/// * purchase date / estimate change recomputes `estimatedEndDate`;
/// * quantity never changes the estimate.
int resolveShelfLifeDays({
  required StorageLocation location,
  required ShelfLifeEstimate? estimate,
  required String category,
  int? manualDays,
}) {
  if (manualDays != null && manualDays >= 1) return manualDays;
  return (estimate ?? fallbackEstimateFor(category)).forLocation(location);
}
