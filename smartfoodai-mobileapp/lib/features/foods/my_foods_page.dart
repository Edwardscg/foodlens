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
  bool _deleting = false, _confirming = false;
  bool get _busy => _loading || _deleting;
  bool _loaded = false;
  bool _lastReset = true;
  String? _error;
  String _search = '';
  int _nextPage = 0, _totalPages = 0, _total = 0;
  @override
  void initState() {
    super.initState();
    _api = FoodsApi(ref.read(authProvider));
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    _lastReset = reset;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _search = _filter.text.trim();
        _items.clear();
        _loaded = false;
        _nextPage = 0;
        _totalPages = 0;
        _total = 0;
      }
    });
    try {
      final result = await _api.list(_nextPage, query: _search);
      if (!mounted) return;
      setState(() {
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
      if (mounted) {
        setState(
          () =>
              _error = 'No pudimos cargar tus alimentos. Inténtalo nuevamente.',
        );
      }
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

  Future<void> _edit(CustomFood food) async {
    final saved = await context.push<bool>('/foods/${food.id}/edit');
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Alimento actualizado')));
    }
    // Confirm the current catalog even if the save response was lost.
    await _load(reset: true);
  }

  Future<void> _delete(CustomFood food) async {
    if (_busy || _confirming) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar alimento?'),
        content: Text(
          'Se eliminará «${food.name}» de Mis alimentos. '
          'Las comidas ya registradas conservarán sus valores originales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _deleting = true);
    String message;
    try {
      await _api.delete(food.id);
      message = 'Alimento eliminado';
    } on ApiFailure catch (failure) {
      message = failure.status == 404
          ? 'El alimento ya no está disponible.'
          : failure.message;
    } catch (_) {
      message = 'No pudimos confirmar la eliminación. Actualiza Mis alimentos para comprobar su estado.';
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis alimentos'),
          leading: IconButton(
            tooltip: 'Volver a mi cuenta',
            icon: const Icon(Icons.arrow_back),
            onPressed: _deleting ? null : () => context.go('/account'),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _busy ? null : () => _load(reset: true),
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
                    enabled: !_busy,
                    maxLength: 120,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(reset: true),
                    decoration: InputDecoration(
                      hintText: 'Buscar en Mis alimentos',
                      suffixIcon: IconButton(
                        tooltip: 'Buscar',
                        onPressed: _busy ? null : () => _load(reset: true),
                        icon: const Icon(Icons.search),
                      ),
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
                              '${_items.length} de $_total alimentos',
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
                            onPressed: _busy
                                ? null
                                : () => _load(reset: _lastReset),
                            child: const Text('Reintentar'),
                          ),
                        ],
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_loaded &&
                            _items.isEmpty &&
                            !_loading &&
                            _error == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                const Icon(Icons.restaurant_menu, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _search.isEmpty
                                      ? 'Todavía no tienes alimentos'
                                      : 'No encontramos alimentos con ese nombre',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _search.isEmpty
                                      ? 'Crea tu primer alimento con sus valores nutricionales.'
                                      : 'Prueba otro nombre o borra la búsqueda para ver todos.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        for (final food in _items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FoodCard(
                              key: ValueKey(food.id),
                              food: food,
                              onEdit: _busy ? null : () => _edit(food),
                              onDelete: _busy ? null : () => _delete(food),
                            ),
                          ),
                        if (_nextPage < _totalPages && _error == null)
                          OutlinedButton(
                            onPressed: _busy ? null : () => _load(),
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
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Crear alimento'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
