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
  final int id;
  final String name, unit;
  final double quantity;
  final MealNutrition nutrition;
  const SavedMealItem(
    this.id,
    this.name,
    this.unit,
    this.quantity,
    this.nutrition,
  );
  factory SavedMealItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'], unit = json['unit'], quantity = json['quantity'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        (unit != 'GRAMS' && unit != 'SERVINGS') ||
        quantity is! num ||
        !quantity.isFinite ||
        quantity <= 0) {
      throw const FormatException('Invalid saved item');
    }
    return SavedMealItem(
      id,
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
  final int version;
  final MealHistoryEntry summary;
  final String timeZone;
  final MealNutrition totals;
  final List<SavedMealItem> items;
  const MealDetail(
    this.version,
    this.summary,
    this.timeZone,
    this.totals,
    this.items,
  );
  factory MealDetail.fromJson(Map<String, dynamic> json) {
    final summary = MealHistoryEntry.fromJson(json);
    final version = json['version'];
    final zone = json['timeZone'];
    final raw = json['items'];
    if (version is! int ||
        version < 0 ||
        zone is! String ||
        zone.isEmpty ||
        raw is! List ||
        raw.isEmpty) {
      throw const FormatException('Invalid saved meal');
    }
    return MealDetail(
      version,
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
