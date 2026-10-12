class DetectedFood {
  final String name;
  final double? estimatedGrams;
  const DetectedFood(this.name, this.estimatedGrams);

  static List<DetectedFood> parseResponse(dynamic data) {
    if (data is! Map || data['foods'] is! List) {
      throw const FormatException('Invalid analysis');
    }
    final items = data['foods'] as List;
    if (items.length > 20) throw const FormatException('Too many foods');
    return List.unmodifiable(
      items.map((item) {
        if (item is! Map ||
            item['name'] is! String ||
            !item.containsKey('estimatedGrams')) {
          throw const FormatException('Invalid food');
        }
        final name = (item['name'] as String).trim();
        final grams = item['estimatedGrams'];
        if (name.isEmpty ||
            name.length > 120 ||
            (grams != null &&
                (grams is! num ||
                    !grams.isFinite ||
                    grams <= 0 ||
                    grams > 10000))) {
          throw const FormatException('Invalid food');
        }
        return DetectedFood(name, (grams as num?)?.toDouble());
      }),
    );
  }
}
