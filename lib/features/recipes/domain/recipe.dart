/// Recipe data models (Contracts §3.2 `Recipe`, §3.3 `FavoriteRecipe`).
///
/// Do not add/rename fields without a contract change (PRD §13.3).
library;

/// A recipe produced by `POST /generate-recipes` and cached per user.
class Recipe {
  const Recipe({
    required this.recipeId,
    required this.name,
    required this.description,
    required this.illustrationKey,
    required this.cuisine,
    required this.cookingTechnique,
    required this.cookingTimeMinutes,
    required this.ingredientsAvailable,
    required this.ingredientsMissing,
    required this.equipment,
    required this.steps,
    required this.generatedAt,
    required this.lastAccessedAt,
  });

  final String recipeId;
  final String name;
  final String description;

  /// Key of a bundled local illustration, never a URL (PRD §6.3).
  final String illustrationKey;
  final String cuisine;
  final String cookingTechnique;
  final int cookingTimeMinutes;
  final List<String> ingredientsAvailable;
  final List<String> ingredientsMissing;
  final List<String> equipment;
  final List<String> steps;
  final DateTime generatedAt;
  final DateTime lastAccessedAt;

  /// Ingredients in the order shown on the Ingredients tab: what the user has
  /// first, then what still has to be prepared.
  List<String> get allIngredients => [
    ...ingredientsAvailable,
    ...ingredientsMissing,
  ];

  Recipe copyWith({DateTime? lastAccessedAt}) => Recipe(
    recipeId: recipeId,
    name: name,
    description: description,
    illustrationKey: illustrationKey,
    cuisine: cuisine,
    cookingTechnique: cookingTechnique,
    cookingTimeMinutes: cookingTimeMinutes,
    ingredientsAvailable: ingredientsAvailable,
    ingredientsMissing: ingredientsMissing,
    equipment: equipment,
    steps: steps,
    generatedAt: generatedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );

  /// Wire format (ISO-8601 UTC dates, Contracts §1).
  Map<String, Object?> toJson() => {
    'recipeId': recipeId,
    'name': name,
    'description': description,
    'illustrationKey': illustrationKey,
    'cuisine': cuisine,
    'cookingTechnique': cookingTechnique,
    'cookingTimeMinutes': cookingTimeMinutes,
    'ingredientsAvailable': ingredientsAvailable,
    'ingredientsMissing': ingredientsMissing,
    'equipment': equipment,
    'steps': steps,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toUtc().toIso8601String(),
  };

  /// Validates a recipe from the AI response, a fixture, or local storage.
  ///
  /// Returns `null` when a required field is missing or invalid so a single
  /// bad recipe cannot break the list (PRD §5.3: validate AI output).
  /// [illustrationKey], [generatedAt] and [lastAccessedAt] are filled in when
  /// absent, because the Worker response does not carry them (Contracts §4.4).
  static Recipe? tryParse(Object? json, {required DateTime now}) {
    if (json is! Map) return null;

    String? text(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    List<String>? list(String key, {bool mayBeEmpty = false}) {
      final v = json[key];
      if (v is! List) return null;
      final items = [
        for (final e in v)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
      if (items.isEmpty && !mayBeEmpty) return null;
      return items;
    }

    DateTime? date(String key) {
      final v = json[key];
      return v is String ? DateTime.tryParse(v) : null;
    }

    final id = text('recipeId');
    final name = text('name');
    final description = text('description');
    final cuisine = text('cuisine');
    final technique = text('cookingTechnique');
    final minutes = json['cookingTimeMinutes'];
    final available = list('ingredientsAvailable', mayBeEmpty: true);
    final missing = list('ingredientsMissing', mayBeEmpty: true);
    final equipment = list('equipment', mayBeEmpty: true);
    // The Instructions tab numbers the steps, so numbering written by the AI
    // would show twice ("1. 1. Boil…").
    final steps = [
      for (final s in list('steps') ?? const <String>[])
        if (_withoutStepNumber(s) case final step when step.isNotEmpty) step,
    ];

    if (id == null ||
        name == null ||
        description == null ||
        cuisine == null ||
        technique == null ||
        minutes is! num ||
        minutes < 1 ||
        available == null ||
        missing == null ||
        equipment == null ||
        steps.isEmpty ||
        available.length + missing.length == 0) {
      return null;
    }

    final generated = date('generatedAt') ?? now;
    return Recipe(
      recipeId: id,
      name: name,
      description: description,
      illustrationKey: text('illustrationKey') ?? illustrationKeyFor(cuisine),
      cuisine: cuisine,
      cookingTechnique: technique,
      cookingTimeMinutes: minutes.round(),
      ingredientsAvailable: available,
      ingredientsMissing: missing,
      equipment: equipment,
      steps: steps,
      generatedAt: generated,
      lastAccessedAt: date('lastAccessedAt') ?? generated,
    );
  }
}

/// "1.", "2)", "(3)" or "Step 4:" at the start of a step. A decimal such as
/// "1.5 liters" is not a step number.
final _stepNumber = RegExp(
  r'^(?:step\s*\d{1,2}\s*[.):-]?|\(\d{1,2}\)|\d{1,2}\s*[.)](?!\d))\s*',
  caseSensitive: false,
);

String _withoutStepNumber(String step) {
  var text = step;
  while (_stepNumber.hasMatch(text)) {
    text = text.replaceFirst(_stepNumber, '');
  }
  return text;
}

/// A saved recipe with a full snapshot, so it opens offline (PRD §3.8).
class FavoriteRecipe {
  const FavoriteRecipe({
    required this.userId,
    required this.recipeSnapshot,
    required this.savedAt,
  });

  final String userId;
  final Recipe recipeSnapshot;
  final DateTime savedAt;

  /// `favoriteId` always equals `recipeId` (Contracts §3.3).
  String get favoriteId => recipeSnapshot.recipeId;

  Map<String, Object?> toJson() => {
    'favoriteId': favoriteId,
    'userId': userId,
    'recipeSnapshot': recipeSnapshot.toJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  static FavoriteRecipe? tryParse(Object? json, {required DateTime now}) {
    if (json is! Map) return null;
    final recipe = Recipe.tryParse(json['recipeSnapshot'], now: now);
    if (recipe == null) return null;
    final saved = json['savedAt'];
    return FavoriteRecipe(
      userId: json['userId'] is String ? json['userId'] as String : '',
      recipeSnapshot: recipe,
      savedAt: (saved is String ? DateTime.tryParse(saved) : null) ?? now,
    );
  }
}

/// Unit tokens that only state how much of an ingredient is used, never its
/// name ("150 g pasta" → "Pasta").
const _ingredientUnits = {
  'g',
  'gr',
  'gram',
  'grams',
  'kg',
  'ml',
  'l',
  'liter',
  'liters',
  'litre',
  'litres',
  'tbsp',
  'tsp',
  'cup',
  'cups',
  'pcs',
  'pc',
  'piece',
  'pieces',
  'clove',
  'cloves',
  'slice',
  'slices',
  'pinch',
  'pinches',
  'handful',
  'handfuls',
  'punnet',
  'punnets',
  'carton',
  'cartons',
  'bunch',
  'bunches',
  'can',
  'cans',
  'jar',
  'jars',
  'pack',
  'packs',
  'packet',
  'packets',
  'stalk',
  'stalks',
  'sprig',
  'sprigs',
  'head',
  'heads',
  'oz',
  'lb',
};

/// Adjectives that describe the state of an ingredient rather than its name.
const _ingredientQualifiers = {
  'fresh',
  'dried',
  'frozen',
  'canned',
  'cooked',
  'raw',
  'chopped',
  'minced',
  'sliced',
  'diced',
  'grated',
  'shredded',
  'ground',
  'whole',
  'large',
  'small',
  'medium',
  'ripe',
  'boneless',
  'skinless',
  'plain',
  'mixed',
  'toasted',
  'boiled',
  'peeled',
  'crushed',
  'halved',
  'trimmed',
  'optional',
};

final _quantityToken = RegExp(r'^\d+(?:[.,/-]\d+)?$');
final _quantityWithUnit = RegExp(r'^(\d+(?:[.,/-]\d+)?)([a-zA-Z]+)$');

/// Short label for a recipe ingredient tag, e.g. "100 g fresh spinach" →
/// "Spinach" and "1 carton whole milk" → "Milk".
///
/// The AI returns the amount inside the ingredient string, but the Home card
/// only has room for the ingredient name (Figma 349:28). Returns an empty
/// string when nothing is left after the amount is removed.
String ingredientTagLabel(String ingredient) {
  final tokens = [
    for (final word in ingredient.trim().split(RegExp(r'\s+')))
      if (word.isNotEmpty) word.replaceAll(RegExp(r'[,;.]+$'), ''),
  ]..removeWhere((word) => word.isEmpty);
  if (tokens.isEmpty) return '';

  var start = 0;
  final first = tokens.first;
  if (_quantityToken.hasMatch(first)) {
    start = 1;
    if (start < tokens.length &&
        _ingredientUnits.contains(tokens[start].toLowerCase())) {
      start++;
    }
  } else {
    final attached = _quantityWithUnit.firstMatch(first);
    if (attached != null &&
        _ingredientUnits.contains(attached.group(2)!.toLowerCase())) {
      start = 1;
    }
  }

  var words = tokens.sublist(start);
  // "Salt, to taste" → "Salt": drop the trailing serving note.
  final toTaste = words.indexWhere((word) => word.toLowerCase() == 'to');
  if (toTaste > 0) words = words.sublist(0, toTaste);
  while (words.length > 1 &&
      _ingredientQualifiers.contains(words.first.toLowerCase())) {
    words = words.sublist(1);
  }
  while (words.length > 1 &&
      _ingredientQualifiers.contains(words.last.toLowerCase())) {
    words = words.sublist(0, words.length - 1);
  }
  if (words.isEmpty) return '';

  return words
      .take(2)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// Cuisines offered by the filter (PRD §3.5). Cuisine describes the regional
/// style of a dish; cooking techniques are a separate field.
const List<String> recipeCuisines = [
  'Indonesian',
  'Italian',
  'Chinese',
  'Japanese',
  'Korean',
  'Western',
];

/// Picks the bundled illustration for a cuisine (PRD §6.3). The set is fixed
/// and shipped inside the app, so it also works offline.
String illustrationKeyFor(String cuisine) {
  final c = cuisine.trim().toLowerCase();
  const known = {
    'indonesian',
    'italian',
    'chinese',
    'japanese',
    'korean',
    'western',
  };
  return 'recipe_${known.contains(c) ? c : 'general'}';
}
