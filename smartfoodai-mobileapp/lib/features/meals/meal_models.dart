import '../foods/food_models.dart';

enum MealType {
  breakfast('BREAKFAST', 'Desayuno'),
  lunch('LUNCH', 'Almuerzo'),
  dinner('DINNER', 'Cena'),
  snack('SNACK', 'Merienda');

  final String apiValue, label;
  const MealType(this.apiValue, this.label);
}

class MealEntry {
  final CustomFood food;
  double quantity;
  MealEntry(this.food)
    : quantity = food.basis == NutritionBasis.per100g ? 100 : 1;
  String get unit => food.basis == NutritionBasis.per100g ? 'g' : 'porciones';
  double get factor =>
      food.basis == NutritionBasis.per100g ? quantity / 100 : quantity;
  double scaled(double value) =>
      double.parse((value * factor).toStringAsFixed(2));
  Map<String, dynamic> toJson() => {
    'foodId': food.id,
    'quantity': quantity,
    'unit': food.basis == NutritionBasis.per100g ? 'GRAMS' : 'SERVINGS',
  };
}
