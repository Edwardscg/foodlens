import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../auth/auth_models.dart';
import 'photo_analysis_api.dart';

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
  final bool canConfirm;
  final Future<void> Function(List<MealEntry>) onConfirm;
  const PhotoFoodReview({
    super.key,
    required this.detected,
    this.canConfirm = true,
    required this.onConfirm,
  });
  @override
  ConsumerState<PhotoFoodReview> createState() => _PhotoFoodReviewState();
}

class _PhotoFoodReviewState extends ConsumerState<PhotoFoodReview> {
  late final FoodsApi _api;
  late final List<ReviewFood> _items;
  bool _choosing = false, _resolving = true;
  late final PhotoAnalysisApi _resolver;
  final _resolutionCancel = CancelToken();
  bool get _busy => _choosing || _resolving;

  Future<void> _resolveAll() async {
    try {
      if (_items.isEmpty) return;
      final results = await _resolver.resolveAll(
        widget.detected,
        _resolutionCancel,
      );
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final selected = results[i].food;
          if (selected != null) {
            _items[i].select(selected);
          } else {
            _items[i].resolutionError = results[i].issue ?? 'Sin coincidencia nutricional completa. Elige o crea el alimento.';
          }
        }
      });
    } catch (error) {
      if (mounted && !_resolutionCancel.isCancelled) {
        setState(() {
          for (final item in _items) {
            item.resolutionError = error is ApiFailure ? error.message : 'No pudimos vincular los alimentos. Puedes elegirlos manualmente.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _api = FoodsApi(ref.read(authProvider));
    _items = widget.detected.map(ReviewFood.new).toList();
    _resolver = PhotoAnalysisApi(ref.read(authProvider));
    _resolveAll();
  }

  @override
  void dispose() {
    _resolutionCancel.cancel();
    _resolver.close();
    _api.dispose();
    super.dispose();
  }

  Future<void> _choose([ReviewFood? item]) async {
    if (_busy || (item == null && _items.length >= 50)) return;
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
          'Revisa los alimentos vinculados y ajusta las cantidades estimadas antes de guardar.',
        ),
        const SizedBox(height: 16),
        if (_resolving) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Buscando coincidencias nutricionales…'),
        ],
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
                  if (entries.every(
                    (entry) => entry.food.basis == NutritionBasis.per100g,
                  ))
                    Text(
                      'Total ración: ${foodNumber(entries.fold<double>(0, (sum, entry) => sum + entry.quantity))} g',
                    ),
                  const SizedBox(height: 12),
                  MacroSummary(
                    energyDistribution: true,
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
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Confianza ${item.detection.confidenceLabel.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      children: [
                        if (item.detection.confidenceReason != null)
                          Text(item.detection.confidenceReason!),
                        const Text(
                          'Valoración orientativa de la identificación original; revisa el alimento y la cantidad.',
                        ),
                        if (item.food?.sourceName != null)
                          Text(
                            'Referencia nutricional: ${item.food!.sourceName}',
                          ),
                      ],
                    ),
                  if (item.resolutionError != null) Text(item.resolutionError!),
                  if (item.entry != null) ...[
                    Text(
                      '${foodNumber(item.entry!.scaled(item.food!.calories))} kcal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'C: ${foodNumber(item.entry!.scaled(item.food!.carbsG))} g · '
                      'P: ${foodNumber(item.entry!.scaled(item.food!.proteinG))} g · '
                      'G: ${foodNumber(item.entry!.scaled(item.food!.fatG))} g',
                    ),
                  ],
                  if (item.food != null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey(item.quantityRevision),
                      initialValue: item.quantity,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Cantidad editable',
                        prefixIcon: IconButton(
                          tooltip: 'Reducir cantidad',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => item.adjust(
                                    item.food!.basis == NutritionBasis.per100g
                                        ? -10
                                        : -1,
                                  ),
                                ),
                          icon: const Icon(Icons.remove),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Aumentar cantidad',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => item.adjust(
                                    item.food!.basis == NutritionBasis.per100g
                                        ? 10
                                        : 1,
                                  ),
                                ),
                          icon: const Icon(Icons.add),
                        ),
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
                        onPressed: _busy ? null : () => _choose(item),
                        icon: const Icon(Icons.search),
                        label: Text(
                          item.food == null
                              ? 'Elegir alimento'
                              : 'Cambiar alimento',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy
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
          onPressed: _busy || _items.length >= 50 ? null : () => _choose(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir alimento'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: !complete || _busy || !widget.canConfirm
              ? null
              : () async {
                  setState(() => _choosing = true);
                  try {
                    await widget.onConfirm(entries);
                  } finally {
                    if (mounted) setState(() => _choosing = false);
                  }
                },
          icon: const Icon(Icons.check),
          label: const Text('Guardar comida'),
        ),
      ],
    );
  }
}
