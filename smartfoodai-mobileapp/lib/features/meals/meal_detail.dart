import 'meal_models.dart';

class MealNutrition {
  final double calories, protein, carbs, fat;
  const MealNutrition(this.calories, this.protein, this.carbs, this.fat);
  factory MealNutrition.fromJson(Map<String, dynamic> json) {
    double read(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid saved nutrition');
      }
      return value.toDouble();
    }

    return MealNutrition(
      read('calories'),
      read('proteinG'),
      read('carbsG'),
      read('fatG'),
    );
  }
}

class SavedMealItem {
  final String name, unit;
  final double quantity;
  final MealNutrition nutrition;
  const SavedMealItem(this.name, this.unit, this.quantity, this.nutrition);
  factory SavedMealItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'], unit = json['unit'], quantity = json['quantity'];
    if (name is! String ||
        name.trim().isEmpty ||
        (unit != 'GRAMS' && unit != 'SERVINGS') ||
        quantity is! num ||
        !quantity.isFinite ||
        quantity <= 0) {
      throw const FormatException('Invalid saved item');
    }
    return SavedMealItem(
      name,
      unit as String,
      quantity.toDouble(),
      MealNutrition.fromJson(
        Map<String, dynamic>.from(json['consumedNutrition'] as Map),
      ),
    );
  }
  String get unitLabel => unit == 'GRAMS' ? 'g' : 'porciones';
}

class MealDetail {
  final MealHistoryEntry summary;
  final String timeZone;
  final MealNutrition totals;
  final List<SavedMealItem> items;
  const MealDetail(this.summary, this.timeZone, this.totals, this.items);
  factory MealDetail.fromJson(Map<String, dynamic> json) {
    final summary = MealHistoryEntry.fromJson(json);
    final zone = json['timeZone'];
    final raw = json['items'];
    if (zone is! String || zone.isEmpty || raw is! List || raw.isEmpty) {
      throw const FormatException('Invalid saved meal');
    }
    return MealDetail(
      summary,
      zone,
      MealNutrition.fromJson(Map<String, dynamic>.from(json['totals'] as Map)),
      List.unmodifiable(
        raw.map(
          (item) =>
              SavedMealItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
    );
  }
}
