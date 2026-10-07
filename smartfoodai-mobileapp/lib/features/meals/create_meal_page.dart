import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import '../foods/food_widgets.dart';
import '../foods/foods_api.dart';
import 'meal_food_picker.dart';
import 'meal_models.dart';
import 'meals_api.dart';

class CreateMealPage extends ConsumerStatefulWidget {
  const CreateMealPage({super.key});
  @override
  ConsumerState<CreateMealPage> createState() => _CreateMealPageState();
}

class _CreateMealPageState extends ConsumerState<CreateMealPage> {
  static const _zoneChannel = MethodChannel('smartfoodai/timezone');
  final _form = GlobalKey<FormState>();
  final _entries = <MealEntry>[];
  late final MealsApi _api;
  late final FoodsApi _foods;
  MealType _type = MealType.lunch;
  DateTime _when = DateTime.now();
  String? _zone, _error;
  bool _saving = false, _dirty = false, _allowExit = false, _dialogOpen = false;
  bool _uncertain = false, _loadingZone = true;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _api = MealsApi(auth);
    _foods = FoodsApi(auth);
    _loadZone();
  }

  @override
  void dispose() {
    _api.dispose();
    _foods.dispose();
    super.dispose();
  }

  Future<void> _loadZone() async {
    setState(() => _loadingZone = true);
    try {
      final zone = await _zoneChannel.invokeMethod<String>('getTimeZone');
      if (zone == null || zone.isEmpty) throw const FormatException();
      if (mounted) {
        setState(() {
          _zone = zone;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos leer la zona horaria del dispositivo. Reintenta desde Android.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingZone = false);
    }
  }

  void _exit({bool saved = false}) {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(saved);
      } else {
        context.go('/home');
      }
    });
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _leave() async {
    if (_saving || _dialogOpen) return;
    _dialogOpen = true;
    final leave =
        !_dirty ||
        await _confirm(
          '¿Salir del registro?',
          _uncertain
              ? 'El resultado del guardado es incierto. Salir no elimina una comida que el servidor haya recibido.'
              : 'Se perderán los datos de esta comida que todavía no has guardado.',
          'Salir',
        );
    _dialogOpen = false;
    if (mounted && leave) _exit();
  }

  Future<void> _addFood() async {
    if (_saving || _dialogOpen) return;
    if (_entries.length >= 50) {
      setState(() => _error = 'Puedes añadir hasta 50 alimentos.');
      return;
    }
    _dialogOpen = true;
    final selection = await showDialog<FoodSelection>(
      context: context,
      builder: (_) => MealFoodPicker(api: _foods),
    );
    _dialogOpen = false;
    if (!mounted || selection == null) return;
    if (selection.food == null) {
      final created = await context.push<bool>('/foods/create');
      if (mounted && created == true) await _addFood();
      return;
    }
    if (_entries.any((item) => item.food.id == selection.food!.id)) {
      setState(
        () => _error = 'Ese alimento ya está añadido. Ajusta su cantidad.',
      );
      return;
    }
    setState(() {
      _entries.add(MealEntry(selection.food!));
      _dirty = true;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (!mounted || date == null) return;
    setState(() {
      _when = DateTime(
        date.year,
        date.month,
        date.day,
        _when.hour,
        _when.minute,
      );
      _dirty = true;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted || time == null) return;
    setState(() {
      _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        time.hour,
        time.minute,
      );
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving || _dialogOpen || _loadingZone || _zone == null || _allowExit) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_entries.isEmpty || _when.isAfter(DateTime.now())) {
      setState(
        () => _error = _entries.isEmpty
            ? 'Añade al menos un alimento.'
            : 'La fecha y hora no pueden estar en el futuro.',
      );
      return;
    }
    if (_uncertain) {
      _dialogOpen = true;
      final retry = await _confirm(
        '¿Enviar otra vez?',
        'La solicitud anterior podría haberse guardado. Enviarla de nuevo puede duplicar la comida.',
        'Enviar de nuevo',
      );
      _dialogOpen = false;
      if (!mounted || !retry) return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final zone = await _zoneChannel.invokeMethod<String>('getTimeZone');
      if (zone != _zone) {
        throw const ApiFailure(
          'La zona horaria cambió. Vuelve a abrir el registro para actualizar la fecha y hora.',
        );
      }
      await _api.create(_type, _when, _zone!, _entries);
      if (mounted) _exit(saved: true);
    } on MealSaveFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _uncertain = _uncertain || error.uncertain;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos verificar la zona horaria. Inténtalo nuevamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No pudimos confirmar el guardado.';
          _uncertain = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    double total(double Function(CustomFood) value) =>
        _entries.fold(0.0, (sum, item) => sum + item.scaled(value(item.food)));
    final calories = total((f) => f.calories);
    final carbs = total((f) => f.carbsG),
        protein = total((f) => f.proteinG),
        fat = total((f) => f.fatG);
    final day =
        '${_when.day.toString().padLeft(2, '0')}/${_when.month.toString().padLeft(2, '0')}/${_when.year}';
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrar comida'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _saving ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDEA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFF8B251C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Momento del día',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in MealType.values)
                        ChoiceChip(
                          label: Text(type.label),
                          selected: type == _type,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() {
                                  _type = type;
                                  _dirty = true;
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(day),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          TimeOfDay.fromDateTime(_when).format(context),
                        ),
                      ),
                    ],
                  ),
                  if (_loadingZone)
                    const LinearProgressIndicator()
                  else if (_zone == null)
                    TextButton(
                      onPressed: _loadZone,
                      child: const Text('Reintentar zona horaria'),
                    )
                  else
                    Text(
                      'Zona horaria: $_zone',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'APORTE ENERGÉTICO ESTIMADO',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${foodNumber(calories)} kcal',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.green,
                          ),
                        ),
                        const SizedBox(height: 20),
                        MacroSummary(carbs: carbs, protein: protein, fat: fat),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Alimentos añadidos (${_entries.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_entries.isEmpty)
                    _card(
                      const Column(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 36,
                            color: AppTheme.green,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Añade al menos un alimento para registrar tu comida.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final entry in _entries)
                    Padding(
                      key: ValueKey(entry.food.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.restaurant,
                                  color: AppTheme.green,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.food.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Quitar ${entry.food.name}',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                          _entries.remove(entry);
                                          _dirty = true;
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            Text(
                              'Aporte: ${foodNumber(entry.scaled(entry.food.calories))} kcal',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: foodNumber(entry.quantity),
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                suffixText: entry.unit,
                              ),
                              onChanged: (text) => setState(() {
                                entry.quantity = parseNutrient(text) ?? 0;
                                _dirty = true;
                              }),
                              validator: (text) {
                                final quantity = parseNutrient(text ?? '');
                                return quantity == null ||
                                        quantity < 0.01 ||
                                        quantity > 10000
                                    ? 'Usa una cantidad entre 0,01 y 10000 (hasta 2 decimales).'
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _addFood,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Añadir alimento'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving || _loadingZone || _zone == null
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? 'Guardando comida…'
                          : _uncertain
                          ? 'Revisar reenvío'
                          : 'Guardar comida',
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _leave,
                    child: const Text('Cancelar y descartar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
