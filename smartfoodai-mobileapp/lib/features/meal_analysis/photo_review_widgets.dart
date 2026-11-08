import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../foods/food_models.dart';

const photoCarbs = Color(0xFF306B80);
const photoProtein = Color(0xFF286B55);
const photoFat = Color(0xFF924600);
const photoInset = Color(0xFFF2F3ED);

class PhotoReviewCard extends StatelessWidget {
  final Widget child;
  const PhotoReviewCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D192B20),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class PhotoNutritionSummary extends StatelessWidget {
  final double calories, carbs, protein, fat;
  final double? grams;
  const PhotoNutritionSummary({
    super.key,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.grams,
  });
  @override
  Widget build(BuildContext context) {
    final energy = [carbs * 4, protein * 4, fat * 9];
    final total = energy.fold<double>(0, (a, b) => a + b);
    final colors = [photoCarbs, photoProtein, photoFat];
    final names = ['Carbos', 'Proteínas', 'Grasas'];
    final gramsValues = [carbs, protein, fat];
    return PhotoReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APORTE ENERGÉTICO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: foodNumber(calories),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(
                            text: ' kcal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(color: AppTheme.green),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total ración',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    grams == null
                        ? 'Porciones mixtas'
                        : '${foodNumber(grams!)} g',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 11,
              child: total <= 0
                  ? const ColoredBox(color: photoInset)
                  : Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          if (energy[i] > 0)
                            Expanded(
                              flex: (energy[i] / total * 10000).round().clamp(
                                1,
                                10000,
                              ),
                              child: ColoredBox(
                                color: colors[i],
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Distribución calórica calculada',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
              ),
              Text(
                'Total ración',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: photoInset,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle, size: 7, color: colors[i]),
                            const SizedBox(width: 4),
                            Text(
                              names[i],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${foodNumber(gramsValues[i])} g',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          total == 0
                              ? '—'
                              : '${(energy[i] / total * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
