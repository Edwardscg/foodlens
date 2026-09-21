enum NutritionBasis {
  per100g('PER_100_G', '100 g'),
  perServing('PER_SERVING', '1 porción');

  final String apiValue;
  final String label;
  const NutritionBasis(this.apiValue, this.label);
  static NutritionBasis fromApi(Object? value) => values.firstWhere(
        (basis) => basis.apiValue == value,
    orElse: () => throw const FormatException('Invalid nutrition basis'),
  );
}

class CustomFood {
  final int id;
  final String name;
  final NutritionBasis basis;
  final double calories, proteinG, carbsG, fatG;
  const CustomFood({
    required this.id,
    required this.name,
    required this.basis,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
  factory CustomFood.fromJson(Map<String, dynamic> json) {
    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid nutrient');
      }
      return value.toDouble();
    }

    final id = json['id'];
    final name = json['name'];
    if (id is! int || id <= 0 || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid food');
    }
    return CustomFood(
      id: id,
      name: name,
      basis: NutritionBasis.fromApi(json['basis']),
      calories: number('calories'),
      proteinG: number('proteinG'),
      carbsG: number('carbsG'),
      fatG: number('fatG'),
    );
  }
}

class FoodPage {
  final List<CustomFood> items;
  final int page, totalPages, totalElements;
  const FoodPage(this.items, this.page, this.totalPages, this.totalElements);
  factory FoodPage.fromJson(Map<String, dynamic> json) {
    final page = json['page'];
    final pages = json['totalPages'];
    final total = json['totalElements'];
    final items = json['items'];
    if (page is! int ||
        pages is! int ||
        total is! int ||
        items is! List ||
        page < 0 ||
        pages < 0 ||
        total < 0) {
      throw const FormatException('Invalid page');
    }
    return FoodPage(
      items
          .map(
            (item) =>
            CustomFood.fromJson(Map<String, dynamic>.from(item as Map)),
      )
          .toList(),
      page,
      pages,
      total,
    );
  }
}

String foodNumber(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');

double? parseNutrient(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final value = double.tryParse(normalized);
  return value != null && value.isFinite && value >= 0 ? value : null;
}
