import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../auth/auth_models.dart';
import 'photo_analysis_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../foods/food_models.dart';
import '../../core/app_theme.dart';
import 'photo_review_widgets.dart';
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

  Future<void> _showDetails(ReviewFood item) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.food?.name ?? item.detectedName),
      content: Text(
        'Confianza de identificación: ${item.detection.confidenceLabel}.\n'
        '${item.detection.confidenceReason ?? "Estimación orientativa; revisa alimento y cantidad."}\n\n'
        'Referencia nutricional: ${item.food?.sourceName ?? "Pendiente"}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );

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
        if (_resolving) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Buscando coincidencias nutricionales…'),
          const SizedBox(height: 20),
        ],
        if (complete)
          PhotoNutritionSummary(
            calories: total((food) => food.calories),
            carbs: total((food) => food.carbsG),
            protein: total((food) => food.proteinG),
            fat: total((food) => food.fatG),
            grams:
                entries.every(
                  (entry) => entry.food.basis == NutritionBasis.per100g,
                )
                ? entries.fold<double>(0, (sum, entry) => sum + entry.quantity)
                : null,
          )
        else if (!_resolving)
          PhotoReviewCard(
            child: Text(
              _items.isEmpty ? 'Añade al menos un alimento.' : 'Completa las coincidencias y cantidades para calcular el aporte nutricional.',
            ),
          ),
        const SizedBox(height: 26),
        const Text(
          'Alimentos detectados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        for (final item in _items) ...[
          _foodCard(item),
          const SizedBox(height: 14),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy || _items.length >= 50 ? null : () => _choose(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir alimento'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.green),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            minimumSize: const Size.fromHeight(54),
          ),
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

  Widget _foodCard(ReviewFood item) {
    final food = item.food;
    final entry = item.entry;
    final grams = food?.basis == NutritionBasis.per100g;
    Widget macro(String label, double value, Color color) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '● ',
              style: TextStyle(color: color, fontSize: 8),
            ),
            TextSpan(text: '${foodNumber(value)} g $label'),
          ],
        ),
        style: const TextStyle(fontSize: 10),
      ),
    );
    return PhotoReviewCard(
      key: ObjectKey(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showDetails(item),
                  child: Text(
                    food?.name ?? item.detectedName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry == null
                    ? '— kcal'
                    : '${foodNumber(entry.scaled(food!.calories))} kcal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (food != null)
            Container(
              padding: const EdgeInsets.only(
                left: 12,
                right: 4,
                top: 6,
                bottom: 6,
              ),
              decoration: BoxDecoration(
                color: photoInset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cantidad editable',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Reducir cantidad',
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => item.adjust(grams ? -10 : -1),
                                ),
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 48,
                          child: TextFormField(
                            key: ValueKey(item.quantityRevision),
                            initialValue: item.quantity,
                            enabled: !_busy,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (value) =>
                                setState(() => item.quantity = value),
                          ),
                        ),
                        Text(
                          grams ? 'g' : 'porc.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar cantidad',
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy
                              ? null
                              : () =>
                                    setState(() => item.adjust(grams ? 10 : 1)),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (food != null && item.validQuantity == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Introduce de 0,01 a 10.000, con hasta 2 decimales.',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
          if (item.resolutionError != null)
            Text(item.resolutionError!, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: entry == null
                    ? Text(
                        _resolving ? 'Vinculando…' : 'Pendiente de vincular',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      )
                    : Wrap(
                        children: [
                          macro('C', entry.scaled(food!.carbsG), photoCarbs),
                          macro('P', entry.scaled(food.proteinG), photoProtein),
                          macro('G', entry.scaled(food.fatG), photoFat),
                        ],
                      ),
              ),
              IconButton(
                tooltip: food == null ? 'Elegir alimento' : 'Cambiar alimento',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: _busy ? null : () => _choose(item),
              ),
              IconButton(
                tooltip: 'Eliminar alimento',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC7463D),
                ),
                onPressed: _busy
                    ? null
                    : () => setState(() => _items.remove(item)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
