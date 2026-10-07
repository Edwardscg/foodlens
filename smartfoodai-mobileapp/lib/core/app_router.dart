import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/account_page.dart';
import '../features/home/home_page.dart';
import '../features/foods/my_foods_page.dart';
import '../features/foods/create_food_page.dart';
import '../features/profile/profile_controller.dart';
import '../features/profile/onboarding_page.dart';
import '../features/profile/profile_status_page.dart';
import '../features/meals/create_meal_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authProvider);
  final profile = ref.read(profileProvider);
  final router = GoRouter(
    initialLocation: '/loading',
    refreshListenable: Listenable.merge([auth, profile]),
    redirect: (context, state) {
      final path = state.uri.path;
      if (auth.status == AuthStatus.restoring)
        return path == '/loading' ? null : '/loading';
      if (auth.status == AuthStatus.offline)
        return path == '/connection' ? null : '/connection';
      if (auth.status == AuthStatus.signedOut) {
        return path == '/login' || path == '/register' ? null : '/login';
      }
      if (profile.profile == null) {
        return path == '/profile-loading' ? null : '/profile-loading';
      }
      if (!profile.profile!.completed) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      return {
            '/home',
            '/account',
            '/foods',
            '/foods/create',
            '/profile/edit',
            '/meals/create',
          }.contains(path)
          ? null
          : '/home';
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
      GoRoute(
        path: '/profile-loading',
        builder: (_, __) => const ProfileStatusPage(),
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const OnboardingPage(editing: true),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
      GoRoute(path: '/meals/create', builder: (_, _) => const CreateMealPage()),
      GoRoute(path: '/foods', builder: (_, __) => const MyFoodsPage()),
      GoRoute(
        path: '/foods/create',
        builder: (_, __) => const CreateFoodPage(),
      ),
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
