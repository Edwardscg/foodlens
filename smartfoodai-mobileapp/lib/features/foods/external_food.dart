class ExternalFood {
  final int id;
  final String name, dataType;
  final double? calories, proteinG, carbsG, fatG;
  const ExternalFood(
    this.id,
    this.name,
    this.dataType,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
  );
  bool get complete =>
      calories != null && proteinG != null && carbsG != null && fatG != null;
  factory ExternalFood.fromJson(Map<String, dynamic> data) {
    final id = data['fdcId'], name = data['name'], type = data['dataType'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 1000 ||
        !{'Foundation', 'SR Legacy'}.contains(type)) {
      throw const FormatException('Invalid external food');
    }
    double? nutrient(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0 || value > 9999999.99) {
        throw const FormatException('Invalid external nutrient');
      }
      return value.toDouble();
    }

    return ExternalFood(
      id,
      name,
      type as String,
      nutrient('calories'),
      nutrient('proteinG'),
      nutrient('carbsG'),
      nutrient('fatG'),
    );
  }
}

class ExternalFoodPage {
  final List<ExternalFood> items;
  final int page, totalPages;
  const ExternalFoodPage(this.items, this.page, this.totalPages);
  factory ExternalFoodPage.fromJson(Map<String, dynamic> data) {
    final items = data['items'],
        page = data['page'],
        pages = data['totalPages'];
    if (items is! List ||
        items.length > 20 ||
        page is! int ||
        page < 0 ||
        pages is! int ||
        pages < 0) {
      throw const FormatException('Invalid external page');
    }
    return ExternalFoodPage(
      List.unmodifiable(
        items.map(
          (item) =>
              ExternalFood.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      page,
      pages,
    );
  }
}
