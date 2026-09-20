import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/account_page.dart';
import '../features/home/home_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authProvider);
  final router = GoRouter(
    initialLocation: '/loading',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      if (auth.status == AuthStatus.restoring)
        return path == '/loading' ? null : '/loading';
      if (auth.status == AuthStatus.offline)
        return path == '/connection' ? null : '/connection';
      if (auth.status == AuthStatus.signedOut) {
        return path == '/login' || path == '/register' ? null : '/login';
      }
      return path == '/home' || path == '/account' ? null : '/home';
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, __) =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/connection', builder: (_, __) => const _ConnectionPage()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const AuthPage(key: ValueKey('login')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) =>
        const AuthPage(key: ValueKey('register'), register: true),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _ConnectionPage extends ConsumerWidget {
  const _ConnectionPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 40),
                  const SizedBox(height: 20),
                  Text(
                    'No pudimos recuperar tu sesión',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.message ??
                        'Verifica tu conexión e inténtalo nuevamente.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.busy ? null : auth.restore,
                    child: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: auth.busy ? null : auth.logout,
                    child: const Text('Volver al inicio de sesión'),
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
