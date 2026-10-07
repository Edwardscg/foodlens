import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import 'meal_detail.dart';
import 'meal_models.dart';
import 'meals_api.dart';
import 'meal_food_picker.dart';
import '../foods/foods_api.dart';

class EditMealPage extends ConsumerStatefulWidget {
  final int mealId;
  const EditMealPage({super.key, required this.mealId});
  @override
  ConsumerState<EditMealPage> createState() => _EditMealPageState();
}

class _EditMealPageState extends ConsumerState<EditMealPage> {
  final _form = GlobalKey<FormState>();
  final _quantities = <int, TextEditingController>{};
  late final MealsApi _api;
  late final FoodsApi _foods;
  final _retained = <SavedMealItem>[];
  final _added = <int, CustomFood>{};
  DateTime? _when;
  String? _dateZone;
  static const _zoneChannel = MethodChannel('smartfoodai/timezone');
  MealDetail? _meal;
  MealType _type = MealType.lunch;
  String? _error;
  bool _loading = true, _saving = false, _dirty = false, _allowExit = false;
  bool _blocked = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    _api = MealsApi(ref.read(authProvider));
    _foods = FoodsApi(ref.read(authProvider));
    _load();
  }

  @override
  void dispose() {
    for (final field in _quantities.values) {
      field.dispose();
    }
    _foods.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meal = await _api.get(widget.mealId);
      if (!mounted) return;
      _retained.addAll(meal.items);
      _when = meal.summary.consumedAt;
      for (final item in meal.items) {
        _quantities[item.id] = TextEditingController(
          text: foodNumber(item.quantity),
        );
      }
      setState(() {
        _meal = meal;
        _type = meal.summary.type;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar la comida.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _exit() {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/history/${widget.mealId}');
      }
    });
  }

  Future<void> _leave() async {
    if (_saving || _confirming) return;
    if (!_dirty) {
      _exit();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Volver al detalle?'),
        content: Text(
          _blocked
              ? 'Se descartará este borrador y podrás comprobar los valores guardados.'
              : 'Se perderán los cambios que todavía no has guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Volver al detalle'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (mounted && discard == true) _exit();
  }

  Future<void> _addFood() async {
    if (_saving || _blocked || _confirming) return;
    if (_retained.length + _added.length >= 50) {
      setState(() => _error = 'Puedes añadir hasta 50 alimentos.');
      return;
    }
    _confirming = true;
    final selection = await showDialog<FoodSelection>(
      context: context,
      builder: (_) => MealFoodPicker(api: _foods),
    );
    _confirming = false;
    if (!mounted || selection == null) return;
    if (selection.food == null) {
      final created = await context.push<bool>('/foods/create');
      if (mounted && created == true) await _addFood();
      return;
    }
    final food = selection.food!;
    if (_retained.any((item) => item.foodId == food.id) ||
        _added.containsKey(-food.id)) {
      setState(
        () => _error = 'Ese alimento ya está añadido. Ajusta su cantidad.',
      );
      return;
    }
    setState(() {
      _added[-food.id] = food;
      _quantities[-food.id] = TextEditingController(
        text: food.basis == NutritionBasis.per100g ? '100' : '1',
      );
      _dirty = true;
    });
  }

  void _remove(int key) {
    setState(() {
      _retained.removeWhere((item) => item.id == key);
      _added.remove(key);
      _dirty = true;
    });
    final controller = _quantities.remove(key);
    WidgetsBinding.instance.addPostFrameCallback((_) => controller?.dispose());
  }

  Future<void> _pickWhen() async {
    if (_saving || _blocked || _confirming) return;
    _confirming = true;
    try {
      final zone = await _zoneChannel.invokeMethod<String>('getTimeZone');
      if (!mounted) return;
      if (zone == null || zone.isEmpty) throw const FormatException();
      final date = await showDatePicker(
        context: context,
        initialDate: _when!.isBefore(DateTime(1970)) ? DateTime(1970) : _when!,
        firstDate: DateTime(1970),
        lastDate: DateTime.now(),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_when!),
      );
      if (!mounted || time == null) return;
      final when = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (when.isAfter(DateTime.now())) {
        setState(
          () => _error = 'La fecha y hora no pueden estar en el futuro.',
        );
        return;
      }
      setState(() {
        _when = when;
        _dateZone = zone;
        _dirty = true;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos leer la zona horaria del dispositivo. Inténtalo desde Android.',
        );
      }
    } finally {
      _confirming = false;
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _confirming ||
        _blocked ||
        _meal == null ||
        !_form.currentState!.validate()) {
      return;
    }
    if (_retained.isEmpty && _added.isEmpty) {
      setState(() => _error = 'La comida necesita al menos un alimento.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_dateZone != null &&
          await _zoneChannel.invokeMethod<String>('getTimeZone') != _dateZone) {
        throw const ApiFailure(
          'La zona horaria cambió. Vuelve al detalle y revisa la fecha.',
        );
      }
      final additions = _added.entries
          .map(
            (entry) =>
                MealEntry(entry.value)
                  ..quantity = parseNutrient(_quantities[entry.key]!.text)!,
          )
          .toList();
      await _api.update(
        _meal!,
        _type,
        {
          for (final item in _retained)
            item.id: parseNutrient(_quantities[item.id]!.text)!,
        },
        added: additions,
        consumedAt: _dateZone == null ? null : _when,
        timeZone: _dateZone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comida actualizada.')));
      _exit();
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _blocked =
              error.status == null ||
              error.status == 404 ||
              error.status == 409 ||
              error.status! >= 500;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'No pudimos confirmar los cambios. Comprueba el detalle antes de intentarlo nuevamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Editar comida'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _saving ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFF8B251C)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_meal == null)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        )
                      else ...[
                        const Text(
                          'Momento del día',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in MealType.values)
                              ChoiceChip(
                                label: Text(type.label),
                                selected: type == _type,
                                onSelected: _saving || _blocked
                                    ? null
                                    : (_) => setState(() {
                                        _type = type;
                                        _dirty = true;
                                      }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Los alimentos conservados mantienen sus nutrientes históricos. Los nuevos usan los valores actuales del catálogo.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 20),
                        if (_when != null)
                          TextButton.icon(
                            onPressed: _saving || _blocked ? null : _pickWhen,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              '${_when!.day}/${_when!.month}/${_when!.year} · ${TimeOfDay.fromDateTime(_when!).format(context)} (hora local)',
                            ),
                          ),
                        for (final item in [
                          ..._retained.map(
                            (item) => (
                              id: item.id,
                              name: item.name,
                              unitLabel: item.unitLabel,
                            ),
                          ),
                          ..._added.entries.map(
                            (entry) => (
                              id: entry.key,
                              name: entry.value.name,
                              unitLabel:
                                  entry.value.basis == NutritionBasis.per100g
                                  ? 'g'
                                  : 'porciones',
                            ),
                          ),
                        ])
                          Container(
                            key: ValueKey(item.id),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Quitar ${item.name}',
                                    onPressed: _saving || _blocked
                                        ? null
                                        : () => _remove(item.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _quantities[item.id],
                                  enabled: !_saving && !_blocked,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad',
                                    suffixText: item.unitLabel,
                                  ),
                                  onChanged: (_) => _dirty = true,
                                  validator: (value) {
                                    final quantity = parseNutrient(value ?? '');
                                    return quantity == null ||
                                            quantity < 0.01 ||
                                            quantity > 10000
                                        ? 'Usa entre 0,01 y 10000, con hasta 2 decimales.'
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _saving || _blocked ? null : _addFood,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Añadir alimento'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving || _blocked ? null : _save,
                          child: Text(
                            _saving ? 'Guardando cambios…' : 'Guardar cambios',
                          ),
                        ),
                      ],
                      TextButton(
                        onPressed: _saving ? null : _leave,
                        child: const Text('Volver al detalle'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
