import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/app_navigation.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../meals/meals_api.dart';
import '../meals/meal_detail.dart';
import '../profile/profile_controller.dart';
import '../foods/food_models.dart';
import '../water/water_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  late final MealsApi _api;
  MealNutrition? _totals;
  int _count = 0, _revision = 0;
  bool _loading = true;
  String? _error;
  Timer? _midnight;
  @override
  void initState() {
    super.initState();
    _api = MealsApi(ref.read(authProvider));
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _revision++;
    _midnight?.cancel();
    _api.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    _midnight?.cancel();
    _midnight = Timer(end.difference(now) + const Duration(seconds: 1), () {
      if (mounted) _load();
    });
    setState(() {
      _loading = true;
      _error = null;
      _totals = null;
    });
    try {
      final summary = await _api.summary(start, end);
      if (mounted && revision == _revision) {
        setState(() {
          _totals = summary.totals;
          _count = summary.count;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'No pudimos cargar el resumen diario.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Widget _progress(
    String label,
    double value,
    double? target,
    String unit,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${foodNumber(value)} / ${target == null ? '—' : foodNumber(target)} $unit',
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: target == null || target <= 0
              ? 0
              : (value / target).clamp(0.0, 1.0),
          color: color,
          backgroundColor: const Color(0xFFE6E9E1),
          minHeight: 5,
        ),
      ],
    ),
  );

  Widget _summary() {
    final goal = ref
        .watch(profileProvider)
        .profile
        ?.dailyCalorieGoal
        ?.toDouble();
    final total = _totals;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu resumen diario',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ] else if (total != null) ...[
            Text(
              '${foodNumber(total.calories)} / ${goal == null ? '—' : foodNumber(goal)} kcal',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.green,
              ),
            ),
            _progress('Energía', total.calories, goal, 'kcal', AppTheme.green),
            _progress(
              'Carbohidratos',
              total.carbs,
              goal == null ? null : goal * 0.5 / 4,
              'g',
              AppTheme.blue,
            ),
            _progress(
              'Proteína',
              total.protein,
              goal == null ? null : goal * 0.2 / 4,
              'g',
              const Color(0xFF935208),
            ),
            _progress(
              'Grasas',
              total.fat,
              goal == null ? null : goal * 0.3 / 9,
              'g',
              AppTheme.green,
            ),
            const SizedBox(height: 16),
            Text(
              _count == 0
                  ? 'Aún no hay comidas registradas hoy.'
                  : '$_count comidas registradas hoy.',
            ),
            const Text(
              'Según la fecha local del dispositivo. Metas orientativas del perfil.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppTheme.green),
            SizedBox(width: 8),
            Text(
              'Smart Food AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            onPressed: () => context.go('/account'),
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.green,
              child: Icon(Icons.person_outline, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  _today(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Hola', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  auth.user?.email ?? '',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                if (auth.notice != null) ...[
                  Text(
                    auth.notice!,
                    style: const TextStyle(color: AppTheme.green),
                  ),
                  const SizedBox(height: 16),
                ],
                _summary(),
                const SizedBox(height: 20),
                WaterCard(refresh: _revision),
                const SizedBox(height: 24),
                const Text(
                  'Registro de comidas',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final photo = _HomeAction(
                      icon: Icons.camera_alt_outlined,
                      title: 'Analizar comida',
                      subtitle: 'Cámara o galería',
                      primary: true,
                      onTap: () async {
                        await context.push<bool>('/analyze');
                        if (mounted) await _load();
                      },
                    );
                    final manual = _HomeAction(
                      icon: Icons.edit_note,
                      title: 'Registro manual',
                      subtitle: 'Registrar comida',
                      onTap: () async {
                        final saved = await context.push<bool>('/meals/create');
                        if (!context.mounted) return;
                        await _load();
                        if (!context.mounted || saved != true) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comida registrada correctamente'),
                          ),
                        );
                      },
                    );
                    if (constraints.maxWidth < 310 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [photo, SizedBox(height: 12), manual],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: photo),
                        SizedBox(width: 12),
                        Expanded(child: manual),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  '',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppNavigation(
        selected: '/home',
        onAnalysisReturn: _load,
      ),
    );
  }

  String _today() {
    const months = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    final now = DateTime.now();
    return 'HOY, ${now.day} DE ${months[now.month - 1]}';
  }
}

Widget _card({required Widget child}) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
    ],
  ),
  child: child,
);

class _HomeAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback? onTap;
  const _HomeAction({
    required this.icon,
    required this.title,
    this.subtitle = 'Próximamente',
    this.primary = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: primary ? AppTheme.green : const Color(0xFFECEEE6),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: primary ? Colors.white : AppTheme.muted),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : AppTheme.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: primary ? const Color(0xFFD5E6DD) : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
