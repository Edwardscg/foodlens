import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../foods/food_models.dart';
import '../foods/food_widgets.dart';
import 'meal_detail.dart';
import 'meals_api.dart';

class MealDetailPage extends ConsumerStatefulWidget {
  final int mealId;
  const MealDetailPage({super.key, required this.mealId});
  @override
  ConsumerState<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends ConsumerState<MealDetailPage> {
  late final MealsApi _api;
  MealDetail? _meal;
  Uint8List? _photo;
  String? _photoError;
  bool _loadingPhoto = false;
  String? _error;
  bool _loading = true, _unavailable = false;
  int _revision = 0;
  bool _deleting = false, _confirmingDelete = false;
  String? _deleteError;
  @override
  void initState() {
    super.initState();
    _api = MealsApi(ref.read(authProvider));
    _load();
  }

  @override
  void didUpdateWidget(covariant MealDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mealId != widget.mealId) _load();
  }

  @override
  void dispose() {
    _revision++;
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _deleteError = null;
      _error = null;
      _meal = null;
      _photo = null;
      _photoError = null;
      _unavailable = false;
    });
    try {
      final meal = await _api.get(widget.mealId);
      if (mounted && revision == _revision) {
        setState(() => _meal = meal);
        if (meal.summary.origin == 'PHOTO') await _loadPhoto(revision);
      }
    } on ApiFailure catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _unavailable = error.status == 404;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'No pudimos cargar el detalle de la comida.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _loadPhoto(int revision) async {
    setState(() {
      _loadingPhoto = true;
      _photoError = null;
    });
    try {
      final image = await _api.photo(widget.mealId);
      if (mounted && revision == _revision) setState(() => _photo = image);
    } on ApiFailure catch (error) {
      if (mounted && revision == _revision)
        setState(() => _photoError = error.message);
    } finally {
      if (mounted && revision == _revision)
        setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _edit() async {
    if (_deleting || _confirmingDelete) return;
    await context.push<void>('/history/${widget.mealId}/edit');
    if (mounted) await _load();
  }

  Future<void> _delete() async {
    if (_deleting || _confirmingDelete || _meal == null) return;
    final meal = _meal!;
    final revision = _revision;
    _confirmingDelete = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('¿Eliminar esta comida?'),
        content: Text(
          '${meal.summary.type.label} · ${foodNumber(meal.totals.calories)} kcal.\nSe quitará del historial. Esta acción no se puede deshacer. Tus alimentos personalizados se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar comida'),
          ),
        ],
      ),
    );
    _confirmingDelete = false;
    if (!mounted || confirmed != true || revision != _revision) return;
    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    try {
      final deleted = await _api.delete(meal.summary.id);
      if (!mounted || revision != _revision) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted ? 'Comida eliminada.' : 'La comida ya no está disponible.',
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _back();
      });
    } on ApiFailure catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _deleteError = error.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _deleteError = 'No pudimos confirmar la eliminación. Comprueba el estado de la comida.',
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _deleting = false);
    }
  }

  void _back() {
    if (_deleting) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/history');
    }
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _content(MealDetail meal) {
    final summary = meal.summary;
    final date = summary.consumedAt;
    final gramsOnly = meal.items.every((item) => item.unit == 'GRAMS');
    final weight = meal.items.fold(0.0, (sum, item) => sum + item.quantity);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (summary.origin == 'PHOTO') ...[
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _photo!,
                height: 240,
                fit: BoxFit.contain,
                cacheWidth: 1000,
                semanticLabel: 'Foto privada de esta comida',
                errorBuilder: (_, _, _) =>
                    const Text('No pudimos mostrar la foto.'),
              ),
            ),
          if (_loadingPhoto) const LinearProgressIndicator(),
          if (_photoError != null) ...[
            Text(_photoError!),
            TextButton(
              onPressed: _loadingPhoto ? null : () => _loadPhoto(_revision),
              child: const Text('Reintentar foto'),
            ),
          ],
          const SizedBox(height: 20),
        ],
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.type.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${TimeOfDay.fromDateTime(date).format(context)}',
              ),
              const Text(
                'Fecha y hora local del dispositivo',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Origen: ${summary.origin == 'MANUAL'
                    ? 'Registro manual'
                    : summary.origin == 'PHOTO'
                    ? 'Registro con foto'
                    : summary.origin}',
              ),
              Text(
                'Zona del registro: ${meal.timeZone}',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('APORTE ENERGÉTICO', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                '${foodNumber(meal.totals.calories)} kcal',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.green,
                ),
              ),
              if (gramsOnly)
                Text('Total de la ración: ${foodNumber(weight)} g'),
              const SizedBox(height: 20),
              MacroSummary(
                carbs: meal.totals.carbs,
                protein: meal.totals.protein,
                fat: meal.totals.fat,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Alimentos confirmados (${meal.items.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final item in meal.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.restaurant, color: AppTheme.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${foodNumber(item.nutrition.calories)} kcal / ${foodNumber(item.quantity)} ${item.unitLabel}',
                          style: const TextStyle(color: AppTheme.green),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Carbohidratos: ${foodNumber(item.nutrition.carbs)} g · Proteína: ${foodNumber(item.nutrition.protein)} g · Grasas: ${foodNumber(item.nutrition.fat)} g',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Estos valores corresponden a la comida guardada. Los cambios posteriores en tus alimentos no modifican este registro.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (_deleteError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _deleteError!,
              style: const TextStyle(color: Color(0xFF8B251C)),
            ),
          ),
          TextButton(
            onPressed: _deleting ? null : _load,
            child: const Text('Comprobar estado de la comida'),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _deleting ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar comida y cantidades'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFADBD8),
            foregroundColor: const Color(0xFFB42318),
          ),
          onPressed: _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          label: Text(_deleting ? 'Eliminando…' : 'Eliminar comida'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _deleting ? null : _back,
          child: const Text('Volver al historial'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de comida'),
        leading: IconButton(
          tooltip: 'Volver al historial',
          onPressed: _deleting ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _meal != null
              ? _content(_meal!)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _unavailable ? Icons.search_off : Icons.error_outline,
                        size: 40,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _unavailable
                              ? 'Esta comida no está disponible.'
                              : _error ?? 'No pudimos cargar la comida.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_unavailable)
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      TextButton(
                        onPressed: _back,
                        child: const Text('Volver al historial'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
