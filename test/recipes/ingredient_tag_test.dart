import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/features/recipes/domain/recipe.dart';

void main() {
  group('ingredientTagLabel', () {
    test('drops the quantity and unit', () {
      expect(ingredientTagLabel('150 g pasta'), 'Pasta');
      expect(ingredientTagLabel('200 ml milk'), 'Milk');
      expect(ingredientTagLabel('2 eggs'), 'Eggs');
      expect(ingredientTagLabel('150g pasta'), 'Pasta');
      expect(ingredientTagLabel('1,5 kg potatoes'), 'Potatoes');
    });

    test('drops preparation adjectives', () {
      expect(ingredientTagLabel('100 g fresh spinach'), 'Spinach');
      expect(ingredientTagLabel('2 large eggs'), 'Eggs');
      expect(ingredientTagLabel('1 carton whole milk'), 'Milk');
      expect(ingredientTagLabel('3 cloves garlic, minced'), 'Garlic');
    });

    test('keeps a two-word name and drops serving notes', () {
      expect(ingredientTagLabel('1 tbsp olive oil'), 'Olive Oil');
      expect(ingredientTagLabel('Chicken breast'), 'Chicken Breast');
      expect(ingredientTagLabel('Salt, to taste'), 'Salt');
    });

    test('returns an empty label when nothing is left', () {
      expect(ingredientTagLabel(''), '');
      expect(ingredientTagLabel('   '), '');
      expect(ingredientTagLabel('100 g'), '');
    });
  });
}
