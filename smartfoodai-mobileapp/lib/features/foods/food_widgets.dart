import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'food_models.dart';

const carbColor = Color(0xFF306B80);
const proteinColor = Color(0xFF924600);
const fatColor = Color(0xFF758179);

class MacroSummary extends StatelessWidget {
  final double carbs, protein, fat;
  const MacroSummary({
    super.key,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
  @override
  Widget build(BuildContext context) {
    final values = [carbs, protein, fat];
    final colors = [carbColor, proteinColor, fatColor];
    final total = carbs + protein + fat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Distribución de macronutrientes por gramos',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? const ColoredBox(color: Color(0xFFE6E9E1))
                  : Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    if (values[i] > 0)
                      Expanded(
                        flex: (values[i] / total * 10000)
                            .round()
                            .clamp(1, 10000)
                            .toInt(),
                        child: ColoredBox(
                          color: colors[i],
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legend('Carbohidratos', carbs, carbColor),
            _legend('Proteína', protein, proteinColor),
            _legend('Grasas', fat, fatColor),
          ],
        ),
      ],
    );
  }

  Widget _legend(String label, double value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 5),
      Text(
        '$label: ${foodNumber(value)} g',
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}

class FoodCard extends StatelessWidget {
  final CustomFood food;
  const FoodCard({super.key, required this.food});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF0E7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, color: AppTheme.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Base de cálculo: ${food.basis.label}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${foodNumber(food.calories)} kcal',
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MacroSummary(
          carbs: food.carbsG,
          protein: food.proteinG,
          fat: food.fatG,
        ),
      ],
    ),
  );
}
