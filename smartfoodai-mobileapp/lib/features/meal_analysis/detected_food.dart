class DetectedFood {
  final String name;
  final String? nutritionQuery;
  final double? estimatedGrams;
  final String? confidence, confidenceReason;
  const DetectedFood(
    this.name,
    this.estimatedGrams, {
    this.nutritionQuery,
    this.confidence,
    this.confidenceReason,
  });
  String get confidenceLabel => switch (confidence) {
    'HIGH' => 'Alta',
    'MEDIUM' => 'Media',
    'LOW' => 'Baja',
    _ => 'No informada',
  };

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
        final confidence = item['confidence'],
            reason = item['confidenceReason'];
        // Older servers may omit both; never infer confidence from quantity.
        if ((confidence != null || reason != null) &&
            (!{'HIGH', 'MEDIUM', 'LOW'}.contains(confidence) ||
                reason is! String ||
                reason.trim().isEmpty ||
                reason.length > 200)) {
          throw const FormatException('Invalid confidence');
        }
        final query = item['nutritionQuery'];
        if (query != null &&
            (query is! String || query.trim().isEmpty || query.length > 120)) {
          throw const FormatException('Invalid nutrition query');
        }
        return DetectedFood(
          name,
          (grams as num?)?.toDouble(),
          nutritionQuery: query as String?,
          confidence: confidence as String?,
          confidenceReason: reason as String?,
        );
      }),
    );
  }
}
