import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        leading: IconButton(
          onPressed: auth.busy ? null : () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Correo electrónico',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(auth.user?.email ?? ''),
              const SizedBox(height: 24),
              const Text(
                'La configuración de tu perfil nutricional estará disponible proximamente.',
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Mis alimentos'),
                subtitle: const Text(
                  'Crea y consulta tus alimentos personalizados',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: auth.busy ? null : () => context.push('/foods'),
              ),
              const SizedBox(height: 32),
              if (auth.message != null) ...[
                Text(auth.message!),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: auth.busy
                    ? null
                    : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      content: const Text(
                        'Podrás volver a entrar con tu correo y contraseña.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await auth.logout();
                },
                child: Text(auth.busy ? 'Cerrando sesión…' : 'Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
