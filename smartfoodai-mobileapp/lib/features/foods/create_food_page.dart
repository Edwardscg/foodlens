import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'food_models.dart';
import 'food_widgets.dart';
import 'foods_api.dart';

class CreateFoodPage extends ConsumerStatefulWidget {
  const CreateFoodPage({super.key});
  @override
  ConsumerState<CreateFoodPage> createState() => _CreateFoodPageState();
}

class _CreateFoodPageState extends ConsumerState<CreateFoodPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _fields = <String, TextEditingController>{
    'calories': TextEditingController(),
    'carbsG': TextEditingController(),
    'proteinG': TextEditingController(),
    'fatG': TextEditingController(),
  };
  late final FoodsApi _api;
  NutritionBasis _basis = NutritionBasis.per100g;
  bool _saving = false, _dirty = false, _allowExit = false, _confirming = false;
  String? _error;
  Map<String, String> _serverErrors = {};
  @override
  void initState() {
    super.initState();
    _api = FoodsApi(ref.read(authProvider));
  }

  @override
  void dispose() {
    _api.dispose();
    _name.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _changed(String key) => setState(() {
    _dirty = true;
    _serverErrors.remove(key);
    _error = null;
  });
  void _exit({bool saved = false}) {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(saved);
      } else {
        context.go('/foods');
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
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderán los datos de este formulario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (mounted && discard == true) _exit();
  }

  Future<void> _save() async {
    if (_saving || _allowExit) return;
    setState(() {
      _serverErrors = {};
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _api.create({
        'name': _name.text.trim(),
        'basis': _basis.apiValue,
        for (final field in _fields.entries)
          field.key: parseNutrient(field.value.text)!,
      });
      if (mounted) _exit(saved: true);
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _serverErrors = error.fields;
        });
        _form.currentState?.validate();
      }
    } catch (_) {
      if (mounted)
        setState(
              () => _error = 'No pudimos confirmar el guardado. Revisa Mis alimentos antes de volver a enviarlo.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = {
      for (final field in _fields.entries)
        field.key: parseNutrient(field.value.text),
    };
    final complete = preview.values.every((value) => value != null);
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crear alimento'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _saving ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EDE4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.green,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alimento privado',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text('Solo tú podrás verlo en Mis alimentos.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Nombre del alimento *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _changed('name'),
                    decoration: InputDecoration(
                      hintText: 'Ej. Avena casera',
                      suffixIcon: IconButton(
                        tooltip: 'Borrar nombre',
                        onPressed: _saving
                            ? null
                            : () {
                          _name.clear();
                          _changed('name');
                        },
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    ),
                    validator: (value) =>
                    _serverErrors['name'] ??
                        ((value ?? '').trim().isEmpty
                            ? 'Ingresa el nombre del alimento'
                            : (value!.length > 120
                            ? 'Usa hasta 120 caracteres'
                            : null)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Base de cálculo nutricional',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final basis in NutritionBasis.values)
                        ChoiceChip(
                          label: Text(
                            basis == NutritionBasis.per100g
                                ? 'Por 100 g'
                                : 'Por porción (plato)',
                          ),
                          selected: _basis == basis,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() {
                            _basis = basis;
                            _dirty = true;
                            _serverErrors.remove('basis');
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa todos los valores para ${_basis.label}. Cambiar la base no convierte las cantidades.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (_serverErrors['basis'] != null)
                    Text(
                      _serverErrors['basis']!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VALORES INGRESADOS',
                          style: TextStyle(fontSize: 12, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${preview['calories'] == null ? '—' : foodNumber(preview['calories']!)} kcal / ${_basis.label}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (complete) ...[
                          MacroSummary(
                            carbs: preview['carbsG']!,
                            protein: preview['proteinG']!,
                            fat: preview['fatG']!,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Distribución por gramos',
                            style: TextStyle(fontSize: 11),
                          ),
                        ] else
                          const Text(
                            'Completa los nutrientes para ver el resumen.',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Parámetros nutricionales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns =
                          constraints.maxWidth >= 320 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20;
                      final width = twoColumns
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _nutrient('calories', 'Energía', 'kcal'),
                          ),
                          SizedBox(
                            width: width,
                            child: _nutrient('carbsG', 'Carbohidratos', 'g'),
                          ),
                          SizedBox(
                            width: width,
                            child: _nutrient('proteinG', 'Proteína', 'g'),
                          ),
                          SizedBox(
                            width: width,
                            child: _nutrient('fatG', 'Grasa total', 'g'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF1EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Todos los campos son obligatorios. Los valores deben ser no negativos y tener hasta 2 decimales. Los campos vacíos no se toman como cero.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando…' : 'Guardar alimento'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _leave,
                    child: const Text('Cancelar'),
                  ),
                  const SafeArea(top: false, child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nutrient(String key, String label, String unit) => TextFormField(
    controller: _fields[key],
    enabled: !_saving,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: key == 'fatG'
        ? TextInputAction.done
        : TextInputAction.next,
    onChanged: (_) => _changed(key),
    decoration: InputDecoration(
      labelText: label,
      suffixText: unit,
      hintText: '0',
      errorMaxLines: 3,
    ),
    validator: (value) {
      if (_serverErrors[key] != null) return _serverErrors[key];
      if ((value ?? '').trim().isEmpty) return 'Campo obligatorio';
      if (parseNutrient(value!) == null)
        return 'Usa un número no negativo: hasta 7 enteros y 2 decimales';
      return null;
    },
  );
}
