import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import 'meal_detail.dart';
import 'meal_models.dart';
import 'meals_api.dart';

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
  MealDetail? _meal;
  MealType _type = MealType.lunch;
  String? _error;
  bool _loading = true, _saving = false, _dirty = false, _allowExit = false;
  bool _blocked = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    _api = MealsApi(ref.read(authProvider));
    _load();
  }

  @override
  void dispose() {
    for (final field in _quantities.values) {
      field.dispose();
    }
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

  Future<void> _save() async {
    if (_saving ||
        _blocked ||
        _meal == null ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.update(_meal!, _type, {
        for (final entry in _quantities.entries)
          entry.key: parseNutrient(entry.value.text)!,
      });
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
                          'Ajusta las cantidades. Se conservarán la fecha y los nutrientes originales de los alimentos.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 20),
                        for (final item in _meal!.items)
                          Container(
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
