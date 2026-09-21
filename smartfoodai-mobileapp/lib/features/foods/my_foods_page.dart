import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'food_models.dart';
import 'food_widgets.dart';
import 'foods_api.dart';

class MyFoodsPage extends ConsumerStatefulWidget {
  const MyFoodsPage({super.key});
  @override
  ConsumerState<MyFoodsPage> createState() => _MyFoodsPageState();
}

class _MyFoodsPageState extends ConsumerState<MyFoodsPage> {
  late final FoodsApi _api;
  final _filter = TextEditingController();
  final List<CustomFood> _items = [];
  bool _loading = false;
  bool _loaded = false;
  bool _lastReset = true;
  String? _error;
  int _nextPage = 0, _totalPages = 0, _total = 0;
  @override
  void initState() {
    super.initState();
    _api = FoodsApi(ref.read(authProvider));
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    _lastReset = reset;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.list(reset ? 0 : _nextPage);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final ids = _items.map((food) => food.id).toSet();
        _items.addAll(result.items.where((food) => ids.add(food.id)));
        _nextPage = result.page + 1;
        _totalPages = result.totalPages;
        _total = result.totalElements;
        _loaded = true;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
              () =>
          _error = 'No pudimos cargar tus alimentos. Inténtalo nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final saved = await context.push<bool>('/foods/create');
    if (!mounted) return;
    if (saved == true) {
      _filter.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Alimento guardado')));
    }
    // Also refresh after an uncertain save followed by returning to the list.
    await _load(reset: true);
  }

  @override
  void dispose() {
    _api.dispose();
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    final visible = _items
        .where((food) => food.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis alimentos'),
        leading: IconButton(
          tooltip: 'Volver a mi cuenta',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _filter,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Filtrar esta lista…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_loaded && _total > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '${_items.length} de $_total alimentos. '
                                '${_nextPage < _totalPages ? "Carga más para ampliar el filtro." : ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          semanticsLabel: _error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _load(reset: _lastReset),
                          child: const Text('Reintentar'),
                        ),
                      ],
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_loaded && visible.isEmpty && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              const Icon(Icons.restaurant_menu, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _items.isEmpty
                                    ? 'Todavía no tienes alimentos'
                                    : 'No hay coincidencias en esta lista',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _items.isEmpty
                                    ? 'Crea tu primer alimento con sus valores nutricionales.'
                                    : 'Prueba otro nombre o carga más alimentos.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      for (final food in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: FoodCard(key: ValueKey(food.id), food: food),
                        ),
                      if (_nextPage < _totalPages)
                        OutlinedButton(
                          onPressed: _loading ? null : () => _load(),
                          child: const Text('Cargar más alimentos'),
                        ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _create,
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Crear alimento'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
