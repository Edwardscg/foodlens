import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import '../foods/foods_api.dart';
import '../foods/external_food_picker.dart';

// El diálogo devuelve un alimento o una solicitud para abrir el formulario existente.
class FoodSelection {
  final CustomFood? food;
  const FoodSelection(this.food);
}

class MealFoodPicker extends StatefulWidget {
  final FoodsApi api;
  final String initialQuery;
  const MealFoodPicker({super.key, required this.api, this.initialQuery = ''});
  @override
  State<MealFoodPicker> createState() => _MealFoodPickerState();
}

class _MealFoodPickerState extends State<MealFoodPicker> {
  final _query = TextEditingController();
  final _items = <CustomFood>[];
  int _page = 0, _pages = 1;
  String _search = '';
  bool _loading = false, _external = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
    _load(reset: true);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _pages = 1;
        _items.clear();
        _search = _query.text.trim();
      }
    });
    try {
      final result = await widget.api.list(_page, query: _search);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _pages = result.totalPages;
        _page++;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar tus alimentos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _external
            ? ExternalFoodPicker(
                api: widget.api,
                initialQuery: _query.text.trim(),
                onSelected: (food) =>
                    Navigator.pop(context, FoodSelection(food)),
                onBack: () {
                  setState(() => _external = false);
                  _load(reset: true);
                },
              )
            : Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Añadir alimento',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    enabled: !_loading,
                    maxLength: 120,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(reset: true),
                    decoration: InputDecoration(
                      hintText: 'Buscar en Mis alimentos',
                      suffixIcon: IconButton(
                        tooltip: 'Buscar',
                        onPressed: _loading ? null : () => _load(reset: true),
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: _loading ? null : () => _load(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(
                    child: _items.isEmpty && !_loading && _error == null
                        ? const Center(
                            child: Text(
                              'No encontramos alimentos. Puedes crear uno personalizado.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView(
                            children: [
                              for (final food in _items)
                                ListTile(
                                  leading: const Icon(Icons.restaurant),
                                  title: Text(food.name),
                                  subtitle: Text(
                                    '${foodNumber(food.calories)} kcal / ${food.basis.label}',
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () => Navigator.pop(
                                    context,
                                    FoodSelection(food),
                                  ),
                                ),
                              if (_page < _pages && !_loading && _error == null)
                                TextButton(
                                  onPressed: () => _load(),
                                  child: const Text('Cargar más'),
                                ),
                            ],
                          ),
                  ),
                  TextButton.icon(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _external = true),
                    icon: const Icon(Icons.public),
                    label: const Text('Buscar en catálogo USDA'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const FoodSelection(null)),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear alimento personalizado'),
                  ),
                ],
              ),
      ),
    ),
  );
}
