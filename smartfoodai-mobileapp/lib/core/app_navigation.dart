import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

class AppNavigation extends StatelessWidget {
  final String selected;
  const AppNavigation({super.key, required this.selected});
  @override
  Widget build(BuildContext context) => SafeArea(
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
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Inicio',
            selected: selected == '/home',
            onTap: () => context.go('/home'),
          ),
          _NavItem(
            icon: Icons.history,
            label: 'Historial',
            selected: selected == '/history',
            onTap: () => context.go('/history'),
          ),
          _NavItem(
            icon: Icons.camera_alt_outlined,
            label: 'Analizar',
            onTap: () => context.push('/analyze'),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Perfil',
            selected: selected == '/account',
            onTap: () => context.go('/account'),
          ),
        ],
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
