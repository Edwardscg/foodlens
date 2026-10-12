import '../foods/food_models.dart';
import '../meals/meal_models.dart';
import 'detected_food.dart';

class ReviewFood {
  final String detectedName;
  final double? estimatedGrams;
  CustomFood? food;
  String quantity = '';

  ReviewFood(DetectedFood detected)
    : detectedName = detected.name,
      estimatedGrams = detected.estimatedGrams;

  void select(CustomFood selected) {
    final previousBasis = food?.basis;
    food = selected;
    if (previousBasis == selected.basis) return;
    // Grams cannot be converted to portions without a known serving weight.
    quantity =
        selected.basis == NutritionBasis.per100g && estimatedGrams != null
        ? foodNumber(estimatedGrams!)
        : '';
  }

  double? get validQuantity {
    final value = parseNutrient(quantity);
    return value != null && value >= 0.01 && value <= 10000 ? value : null;
  }

  MealEntry? get entry {
    final selected = food;
    final amount = validQuantity;
    if (selected == null || amount == null) return null;
    return MealEntry(selected)..quantity = amount;
  }
}
