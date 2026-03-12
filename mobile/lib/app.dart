import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/auth/providers/role_provider.dart';
import 'features/profile/screens/profile_list_screen.dart';
import 'features/profile/screens/create_profile_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/device/screens/device_list_screen.dart';
import 'features/device/screens/add_device_screen.dart';
import 'features/device/screens/scan_qr_screen.dart';
import 'shared/models/profile_model.dart';
import 'core/theme/app_theme.dart';

class SplashLoader extends ConsumerWidget {
  const SplashLoader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to KidFun', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/profiles'),
              child: const Text('Quản lý hồ sơ các bé'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/devices'),
              child: const Text('Quản lý thiết bị'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              child: const Text('Đăng xuất'),
            )
          ],
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final roleState = ref.watch(roleProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashLoader(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfileListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateProfileScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final profile = state.extra as ProfileModel;
              return EditProfileScreen(profile: profile);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DeviceListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddDeviceScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (context, state) => const ScanQrScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isAuthScreen = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isRoleSelection = state.matchedLocation == '/role-selection';

      if (authState is AuthLoading || roleState.isLoading) {
        return isSplash ? null : '/splash';
      }

      final role = roleState.valueOrNull;

      // 1. Check Role Selection
      if (role == null) {
        return isRoleSelection ? null : '/role-selection';
      }

      // 2. Child Role bypasses Login and gets forced to scan UI
      if (role == 'child') {
        if (!state.matchedLocation.startsWith('/devices/scan')) {
          // You could go to a ChildHomeScreen here actually, but scanning is requested.
          return '/devices/scan';
        }
        return null; // Already inside permissible route for child
      }

      // 3. Parent Role handling (Auth check)
      if (authState is AuthUnauthenticated || authState is AuthError) {
        return isAuthScreen ? null : '/login';
      }

      if (authState is AuthAuthenticated) {
        // Redirect to Home if logged in, but trying to access Auth or RoleSelection screens
        if (isAuthScreen || isSplash || isRoleSelection) {
          return '/home';
        }
      }

      return null;
    },
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'KidFun',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
