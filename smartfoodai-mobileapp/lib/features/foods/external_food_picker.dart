import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'external_food.dart';
import 'food_models.dart';
import 'foods_api.dart';

class ExternalFoodPicker extends StatefulWidget {
  final FoodsApi api;
  final String initialQuery;
  final ValueChanged<CustomFood> onSelected;
  final VoidCallback onBack;
  const ExternalFoodPicker({
    super.key,
    required this.api,
    required this.initialQuery,
    required this.onSelected,
    required this.onBack,
  });
  @override
  State<ExternalFoodPicker> createState() => _ExternalFoodPickerState();
}

class _ExternalFoodPickerState extends State<ExternalFoodPicker> {
  final _query = TextEditingController(), _name = TextEditingController();
  final _items = <ExternalFood>[];
  final _form = GlobalKey<FormState>();
  ExternalFood? _detail;
  int? _detailId;
  int _page = 0, _pages = 0;
  String _search = '';
  String? _error;
  bool _busy = false, _saving = false, _uncertain = false, _searched = false;

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _searchFoods({bool reset = false}) async {
    if (_busy) return;
    final query = reset ? _query.text.trim() : _search;
    if (query.isEmpty || query.length > 120) {
      setState(() => _error = 'Escribe un alimento de hasta 120 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      if (reset) {
        _page = 0;
        _pages = 0;
        _items.clear();
        _search = query;
      }
    });
    try {
      final result = await widget.api.searchExternal(_search, _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page++;
        _pages = result.totalPages;
        _searched = true;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDetail(int id) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _detailId = id;
      _detail = null;
      _error = null;
      _uncertain = false;
    });
    try {
      final detail = await widget.api.externalDetail(id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _name.text = detail.name.length <= 120 ? detail.name : '';
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy ||
        _uncertain ||
        _detail?.complete != true ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _saving = true;
      _error = null;
    });
    try {
      final food = await widget.api.importExternal(
        _detail!.id,
        _name.text.trim(),
      );
      if (mounted) widget.onSelected(food);
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _uncertain = error.status == null || error.status! >= 500;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uncertain = true;
          _error = 'No pudimos confirmar la importación. Revisa Mis alimentos.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  void _back() {
    if (_busy) return;
    if (_detailId != null && !_uncertain) {
      setState(() {
        _detailId = null;
        _detail = null;
        _error = null;
      });
    } else {
      widget.onBack();
    }
  }

  String _value(double? value, String unit) =>
      value == null ? 'Sin datos' : '${foodNumber(value)} $unit';

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : _back,
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                'Catálogo USDA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Fuente: USDA FoodData Central. Los nombres y las búsquedas pueden requerir términos en inglés.',
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Semantics(liveRegion: true, child: Text(_error!)),
                  if (!_uncertain && !_saving)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_detailId != null) {
                                _loadDetail(_detailId!);
                              } else {
                                _searchFoods(reset: _search.isEmpty);
                              }
                            },
                      child: const Text('Reintentar'),
                    ),
                ],
                if (_detailId == null) ...[
                  TextField(
                    controller: _query,
                    enabled: !_busy,
                    maxLength: 120,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchFoods(reset: true),
                    decoration: InputDecoration(
                      labelText: 'Buscar alimento',
                      hintText: 'Por ejemplo: rice',
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () => _searchFoods(reset: true),
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  if (_searched && _items.isEmpty && !_busy && _error == null)
                    const Text(
                      'No encontramos resultados. Prueba otro término o usa Mis alimentos.',
                    ),
                  for (final food in _items)
                    ListTile(
                      title: Text(food.name),
                      subtitle: Text(food.dataType),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _loadDetail(food.id),
                    ),
                  if (_page < _pages && _page <= 999 && _error == null)
                    TextButton(
                      onPressed: _busy ? null : () => _searchFoods(),
                      child: const Text('Cargar más'),
                    ),
                ] else if (_detail != null) ...[
                  Text(
                    _detail!.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('USDA · ${_detail!.dataType} · ID ${_detail!.id}'),
                  const SizedBox(height: 12),
                  const Text('Valores por 100 g'),
                  Text('Energía: ${_value(_detail!.calories, 'kcal')}'),
                  Text('Carbohidratos: ${_value(_detail!.carbsG, 'g')}'),
                  Text('Proteína: ${_value(_detail!.proteinG, 'g')}'),
                  Text('Grasas: ${_value(_detail!.fatG, 'g')}'),
                  const SizedBox(height: 16),
                  if (!_detail!.complete)
                    const Text(
                      'Faltan datos nutricionales. Elige otro alimento o crea uno personalizado con datos completos.',
                    ),
                  Form(
                    key: _form,
                    child: TextFormField(
                      controller: _name,
                      enabled: !_busy && !_uncertain,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nombre en Mis alimentos',
                      ),
                      validator: (value) =>
                          value == null ||
                              value.trim().isEmpty ||
                              value.length > 120
                          ? 'Escribe un nombre de hasta 120 caracteres.'
                          : null,
                    ),
                  ),
                  const Text(
                    'Se creará una copia privada por 100 g. Los valores se consultarán de nuevo al importar.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || _uncertain || !_detail!.complete
                        ? null
                        : _import,
                    child: Text(
                      _saving ? 'Importando…' : 'Importar y seleccionar',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : widget.onBack,
                  child: const Text('Volver a Mis alimentos'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
