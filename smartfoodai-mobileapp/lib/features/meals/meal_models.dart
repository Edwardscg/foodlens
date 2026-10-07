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

class MealHistoryEntry {
  final int id;
  final MealType type;
  final DateTime consumedAt;
  final double calories;
  final String origin;
  final List<String> foods;
  const MealHistoryEntry(
    this.id,
    this.type,
    this.consumedAt,
    this.calories,
    this.origin,
    this.foods,
  );

  factory MealHistoryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = MealType.values.firstWhere(
      (t) => t.apiValue == json['mealType'],
      orElse: () => throw const FormatException('Invalid meal type'),
    );
    final when = DateTime.tryParse(json['consumedAt'] as String? ?? '');
    final totals = json['totals'];
    final calories = totals is Map ? totals['calories'] : null;
    final items = json['items'];
    final origin = json['origin'];
    if (id is! int ||
        id <= 0 ||
        when == null ||
        !when.isUtc ||
        calories is! num ||
        !calories.isFinite ||
        calories < 0 ||
        items is! List ||
        origin is! String) {
      throw const FormatException('Invalid meal');
    }
    final names = items.map((item) {
      if (item is! Map || item['name'] is! String) {
        throw const FormatException('Invalid item');
      }
      return item['name'] as String;
    }).toList();
    return MealHistoryEntry(
      id,
      type,
      when.toLocal(),
      calories.toDouble(),
      origin,
      names,
    );
  }
}

class MealHistoryPage {
  final List<MealHistoryEntry> items;
  final int page, totalPages, totalElements;
  const MealHistoryPage(
    this.items,
    this.page,
    this.totalPages,
    this.totalElements,
  );
  factory MealHistoryPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'],
        page = json['page'],
        pages = json['totalPages'],
        total = json['totalElements'];
    if (items is! List ||
        page is! int ||
        page < 0 ||
        pages is! int ||
        pages < 0 ||
        total is! int ||
        total < 0) {
      throw const FormatException('Invalid meal page');
    }
    return MealHistoryPage(
      items
          .map(
            (item) => MealHistoryEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      page,
      pages,
      total,
    );
  }
}
