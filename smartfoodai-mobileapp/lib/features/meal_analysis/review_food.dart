import '../foods/food_models.dart';
import '../meals/meal_models.dart';
import 'detected_food.dart';

class ReviewFood {
  final DetectedFood detection;
  final String detectedName;
  final double? estimatedGrams;
  CustomFood? food;
  String quantity = '';
  int quantityRevision = 0;
  String? resolutionError;

  ReviewFood(DetectedFood detected)
    : detection = detected,
      detectedName = detected.name,
      estimatedGrams = detected.estimatedGrams;

  void select(CustomFood selected) {
    final previousBasis = food?.basis;
    food = selected;
    quantityRevision++;
    resolutionError = null;
    if (previousBasis == selected.basis) return;
    // Grams cannot be converted to portions without a known serving weight.
    quantity =
        selected.basis == NutritionBasis.per100g && estimatedGrams != null
        ? foodNumber(estimatedGrams!)
        : '';
  }

  void adjust(double delta) {
    final value = ((validQuantity ?? 0) + delta).clamp(0.01, 10000).toDouble();
    quantity = foodNumber(value);
    quantityRevision++;
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
