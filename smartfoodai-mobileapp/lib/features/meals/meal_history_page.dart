import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_navigation.dart';
import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import 'meal_models.dart';
import 'meals_api.dart';

class MealHistoryScreen extends ConsumerStatefulWidget {
  const MealHistoryScreen({super.key});
  @override
  ConsumerState<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends ConsumerState<MealHistoryScreen> {
  late final MealsApi _api;
  late DateTimeRange _range;
  final _items = <MealHistoryEntry>[];
  bool _loading = false;
  String? _error;
  int _nextPage = 0, _totalPages = 1, _total = 0, _revision = 0;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    _api = MealsApi(ref.read(authProvider));
    final today = _today;
    _range = DateTimeRange(
      start: DateTime(today.year, today.month, today.day - today.weekday + 1),
      end: today,
    );
    _load(reset: true);
  }

  @override
  void dispose() {
    _revision++;
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final revision = ++_revision;
    final range = _range;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _nextPage = 0;
        _totalPages = 1;
        _total = 0;
      }
    });
    try {
      final result = await _api.list(
        range.start,
        DateTime(range.end.year, range.end.month, range.end.day + 1),
        _nextPage,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(result.items.where((item) => ids.add(item.id)));
        _nextPage = result.page + 1;
        _totalPages = result.totalPages;
        _total = result.totalElements;
      });
    } on ApiFailure catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'No pudimos recuperar tus comidas.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  void _select(DateTimeRange range) {
    final days =
        DateTime.utc(range.end.year, range.end.month, range.end.day)
            .difference(
              DateTime.utc(
                range.start.year,
                range.start.month,
                range.start.day,
              ),
            )
            .inDays +
        1;
    if (days > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un máximo de 31 días.')),
      );
      return;
    }
    setState(() => _range = range);
    _load(reset: true);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: _today,
      initialDateRange: _range,
      helpText: 'Seleccionar periodo (máximo 31 días)',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
    );
    if (mounted && range != null) _select(range);
  }

  Future<void> _register() async {
    final saved = await context.push<bool>('/meals/create');
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Comida registrada.')));
    await _load(reset: true);
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _dayLabel(DateTime date) =>
      DateUtils.isSameDay(date, _today) ? 'Hoy, ${_date(date)}' : _date(date);

  Future<void> _openMeal(int id) async {
    await context.push<void>('/history/$id');
    if (mounted) await _load(reset: true);
  }

  Widget _meal(MealHistoryEntry meal) => Semantics(
    button: true,
    child: InkWell(
      onTap: () => _openMeal(meal.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant, color: AppTheme.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        meal.type.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        TimeOfDay.fromDateTime(meal.consumedAt).format(context),
                      ),
                      Text(
                        meal.origin == 'MANUAL' ? 'Manual' : 'Foto',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(meal.foods.join(', ')),
                  const SizedBox(height: 6),
                  Text(
                    '${foodNumber(meal.calories)} kcal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.green,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Perfil',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigation(selected: '/history'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month,
                      color: AppTheme.green,
                    ),
                    title: Text(
                      '${_date(_range.start)} – ${_date(_range.end)}',
                    ),
                    subtitle: const Text('Cambiar periodo'),
                    trailing: const Icon(Icons.expand_more),
                    onTap: _pickRange,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Hoy'),
                      onPressed: () =>
                          _select(DateTimeRange(start: today, end: today)),
                    ),
                    ActionChip(
                      label: const Text('Esta semana'),
                      onPressed: () => _select(
                        DateTimeRange(
                          start: DateTime(
                            today.year,
                            today.month,
                            today.day - today.weekday + 1,
                          ),
                          end: today,
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Este mes'),
                      onPressed: () => _select(
                        DateTimeRange(
                          start: DateTime(today.year, today.month),
                          end: today,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fechas y horas según la zona actual de tu dispositivo.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF8B251C)),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Reintentar'),
                  ),
                ],
                if (!_loading && _error == null && _items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppTheme.green,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No hay comidas registradas en este periodo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Puedes seleccionar otras fechas o registrar una comida.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _register,
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar comida'),
                        ),
                        TextButton(
                          onPressed: _pickRange,
                          child: const Text('Cambiar periodo'),
                        ),
                      ],
                    ),
                  ),
                if (_items.isNotEmpty) ...[
                  Text(
                    '$_total comidas en el periodo',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i == 0 ||
                        !DateUtils.isSameDay(
                          _items[i - 1].consumedAt,
                          _items[i].consumedAt,
                        ))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _dayLabel(_items[i].consumedAt),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    _meal(_items[i]),
                  ],
                  if (_nextPage < _totalPages && _error == null)
                    TextButton(
                      onPressed: _loading ? null : () => _load(),
                      child: const Text('Cargar más'),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _register,
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar comida'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
