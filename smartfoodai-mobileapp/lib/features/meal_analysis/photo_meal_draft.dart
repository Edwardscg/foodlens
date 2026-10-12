import 'dart:typed_data';

import '../meals/meal_models.dart';

class PhotoMealDraft {
  final Uint8List image;
  final List<MealEntry> entries;
  PhotoMealDraft(this.image, List<MealEntry> entries)
    : entries = List.unmodifiable(
        entries.map(
          (entry) => MealEntry(entry.food)..quantity = entry.quantity,
        ),
      );
}
