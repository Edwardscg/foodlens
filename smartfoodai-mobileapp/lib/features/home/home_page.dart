import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: ListView(
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
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu resumen diario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'El resumen estará disponible cuando guardes tus comidas.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 22),
                    for (final item in [
                      ('Carbohidratos', AppTheme.blue),
                      ('Proteína', Color(0xFF935208)),
                      ('Grasa', AppTheme.green),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: item.$2),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.$1)),
                            const Text(
                              '—',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Registro de comidas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  const photo = _HomeAction(
                    icon: Icons.camera_alt_outlined,
                    title: 'Analizar comida',
                    primary: true,
                  );
                  final manual = _HomeAction(
                    icon: Icons.edit_note,
                    title: 'Registro manual',
                    subtitle: 'Crear alimento',
                    onTap: () async {
                      final saved = await context.push<bool>('/foods/create');
                      if (!context.mounted || saved != true) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alimento guardado en Mis alimentos')),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4E8DF))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const _NavItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                selected: true,
              ),
              const _NavItem(
                icon: Icons.history,
                label: 'Historial',
                disabled: true,
              ),
              const _NavItem(
                icon: Icons.camera_alt_outlined,
                label: 'Analizar',
                disabled: true,
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                onTap: () => context.go('/account'),
              ),
            ],
          ),
        ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected, disabled;
  final VoidCallback? onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? const Color(0xFF99A29B)
        : selected
        ? AppTheme.green
        : AppTheme.muted;
    return Semantics(
      selected: selected,
      enabled: !disabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
