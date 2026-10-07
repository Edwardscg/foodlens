import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'profile_controller.dart';

class ProfileStatusPage extends ConsumerWidget {
  const ProfileStatusPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profile.loading || profile.error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Preparando tu perfil…'),
                  ] else ...[
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 16),
                    Text(profile.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: profile.load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: auth.busy ? null : auth.logout,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
