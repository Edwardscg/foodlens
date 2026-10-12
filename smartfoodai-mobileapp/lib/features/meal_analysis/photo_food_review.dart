import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../foods/food_models.dart';
import '../foods/food_widgets.dart';
import '../foods/foods_api.dart';
import '../meals/meal_food_picker.dart';
import '../meals/meal_models.dart';
import 'detected_food.dart';
import 'review_food.dart';

class PhotoFoodReview extends ConsumerStatefulWidget {
  final List<DetectedFood> detected;
  const PhotoFoodReview({super.key, required this.detected});
  @override
  ConsumerState<PhotoFoodReview> createState() => _PhotoFoodReviewState();
}

class _PhotoFoodReviewState extends ConsumerState<PhotoFoodReview> {
  late final FoodsApi _api;
  late final List<ReviewFood> _items;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _api = FoodsApi(ref.read(authProvider));
    _items = widget.detected.map(ReviewFood.new).toList();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _choose([ReviewFood? item]) async {
    if (_choosing || (item == null && _items.length >= 50)) return;
    setState(() => _choosing = true);
    try {
      while (mounted) {
        final selection = await showDialog<FoodSelection>(
          context: context,
          builder: (_) => MealFoodPicker(
            api: _api,
            initialQuery: item?.food?.name ?? item?.detectedName ?? '',
          ),
        );
        if (!mounted || selection == null) return;
        if (selection.food == null) {
          final created = await context.push<bool>('/foods/create');
          if (!mounted || created != true) return;
          continue;
        }
        setState(() {
          final target = item ?? ReviewFood(const DetectedFood('', null));
          target.select(selection.food!);
          if (item == null) _items.add(target);
        });
        return;
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _items
        .map((item) => item.entry)
        .whereType<MealEntry>()
        .toList();
    final complete = _items.isNotEmpty && entries.length == _items.length;
    double total(double Function(CustomFood) nutrient) => entries.fold<double>(
      0,
      (sum, entry) => sum + entry.scaled(nutrient(entry.food)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Revisar alimentos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige el alimento correspondiente de Mis alimentos y revisa la cantidad. Puedes crear uno si no está en tu catálogo.',
        ),
        const SizedBox(height: 16),
        if (complete)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${foodNumber(total((food) => food.calories))} kcal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  MacroSummary(
                    carbs: total((food) => food.carbsG),
                    protein: total((food) => food.proteinG),
                    fat: total((food) => food.fatG),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Estimación del borrador. Todavía no se ha registrado la comida.',
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _items.isEmpty ? 'Añade al menos un alimento.' : 'Completa los alimentos y sus cantidades para calcular el aporte nutricional.',
            ),
          ),
        for (final item in _items)
          Card(
            key: ObjectKey(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.food?.name ?? item.detectedName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (item.detectedName.isNotEmpty)
                    Text('Detectado: ${item.detectedName}'),
                  if (item.estimatedGrams != null)
                    Text(
                      'Estimación de la foto: ${foodNumber(item.estimatedGrams!)} g',
                    ),
                  if (item.food == null)
                    const Text('Información nutricional pendiente'),
                  if (item.food != null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey(item.food!.id),
                      initialValue: item.quantity,
                      enabled: !_choosing,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        suffixText: item.food!.basis == NutritionBasis.per100g
                            ? 'g'
                            : 'porciones',
                      ),
                      onChanged: (value) =>
                          setState(() => item.quantity = value),
                      validator: (_) => item.validQuantity == null
                          ? 'Introduce de 0,01 a 10.000, con hasta 2 decimales.'
                          : null,
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _choosing ? null : () => _choose(item),
                        icon: const Icon(Icons.search),
                        label: Text(
                          item.food == null
                              ? 'Elegir alimento'
                              : 'Cambiar alimento',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _choosing
                            ? null
                            : () => setState(() => _items.remove(item)),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _choosing || _items.length >= 50 ? null : () => _choose(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir alimento'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
