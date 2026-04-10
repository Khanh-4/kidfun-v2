import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'shared/models/profile_model.dart';
import 'shared/models/device_model.dart';
import 'shared/widgets/time_extension_listener.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/role_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/screens/profile_list_screen.dart';
import 'features/profile/screens/create_profile_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/app_blocking_screen.dart';
import 'features/profile/screens/app_usage_report_screen.dart';
import 'features/device/providers/device_provider.dart';
import 'features/device/screens/device_list_screen.dart';
import 'features/device/screens/add_device_screen.dart';
import 'features/device/screens/scan_qr_screen.dart';
import 'features/device/screens/child_dashboard_screen.dart';
import 'features/device/screens/child_request_time_screen.dart';
import 'features/time_limit/screens/time_limit_screen.dart';
import 'features/location/screens/map_screen.dart';
import 'features/location/screens/location_history_screen.dart';
import 'features/location/screens/sos_alert_screen.dart';
import 'features/location/screens/sos_history_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      await ref.read(profileProvider.notifier).fetchProfiles();
      await ref.read(deviceProvider.notifier).fetchDevices();
    } catch (e) {
      if (e.toString().contains('401')) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          await ref.read(profileProvider.notifier).fetchProfiles();
          await ref.read(deviceProvider.notifier).fetchDevices();
        }
      }
    }
    try {
      if (mounted) {
        await ref.read(authProvider.notifier).sendFcmTokenIfAvailable();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final deviceState = ref.watch(deviceProvider);

    final userName = authState is AuthAuthenticated
        ? authState.user.fullName.split(' ').last
        : 'Phụ huynh';

    final profiles =
        profileState is ProfileLoaded ? profileState.profiles : <ProfileModel>[];
    final devices =
        deviceState is DeviceLoaded ? deviceState.devices : <DeviceModel>[];

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.indigo600,
        child: CustomScrollView(
          slivers: [
            _buildSliverHeader(userName),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildStats(profiles, devices),
                  const SizedBox(height: 24),
                  _buildProfilesSection(profiles, profileState),
                  const SizedBox(height: 24),
                  _buildDevicesSection(devices, deviceState),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profiles/create'),
        backgroundColor: AppColors.indigo600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Thêm hồ sơ',
          style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(String userName) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.indigo600,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate how collapsed the app bar is (0.0 = fully expanded, 1.0 = fully collapsed)
          final top = constraints.biggest.height;
          final statusBarHeight = MediaQuery.of(context).padding.top;
          final minHeight = kToolbarHeight + statusBarHeight;
          const maxHeight = 160.0 + 0; // expandedHeight
          final expandRatio = ((top - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);
          
          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.linkDeviceGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, statusBarHeight + kToolbarHeight + 8, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xin chào, $userName!',
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bảng điều khiển phụ huynh',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            title: Opacity(
              opacity: 1.0 - expandRatio,
              child: Text(
                'KidFun',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
          );
        },
      ),
      actions: [
        IconButton(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          tooltip: 'Đăng xuất',
        ),
      ],
    );
  }

  Widget _buildStats(List<ProfileModel> profiles, List<DeviceModel> devices) {
    final onlineCount = devices.where((d) => d.isOnline).length;
    return Row(
      children: [
        _buildStatCard('${profiles.length}', 'Hồ sơ',
            Icons.child_care_rounded, AppColors.indigo600,
            AppColors.requestBg),
        const SizedBox(width: 12),
        _buildStatCard('${devices.length}', 'Thiết bị',
            Icons.devices_rounded, AppColors.purple600,
            const Color(0xFFF5F3FF)),
        const SizedBox(width: 12),
        _buildStatCard('$onlineCount', 'Online',
            Icons.wifi_rounded, AppColors.emerald400,
            AppColors.successBg),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon,
      Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                  fontSize: 11, color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesSection(
      List<ProfileModel> profiles, ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hồ sơ các bé',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800)),
            TextButton(
              onPressed: () => context.push('/profiles'),
              child: Text('Xem tất cả',
                  style: GoogleFonts.nunito(
                      color: AppColors.indigo600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state is ProfileLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (profiles.isEmpty)
          _buildEmptyCard(
            icon: Icons.child_care_rounded,
            title: 'Chưa có hồ sơ nào',
            subtitle: 'Nhấn + để thêm hồ sơ cho con',
            onTap: () => context.push('/profiles/create'),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildProfileCard(profiles[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileCard(ProfileModel profile) {
    final initials =
        profile.profileName.isNotEmpty ? profile.profileName[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () => context.push('/profiles'),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.linkDeviceGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.profileName,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (profile.age != null)
              Text('${profile.age} tuổi',
                  style: GoogleFonts.nunito(
                      fontSize: 10, color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSection(
      List<DeviceModel> devices, DeviceState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Thiết bị',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800)),
            TextButton(
              onPressed: () => context.push('/devices'),
              child: Text('Xem tất cả',
                  style: GoogleFonts.nunito(
                      color: AppColors.indigo600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state is DeviceLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (devices.isEmpty)
          _buildEmptyCard(
            icon: Icons.devices_rounded,
            title: 'Chưa có thiết bị nào',
            subtitle: 'Thêm thiết bị để kết nối với con',
            onTap: () => context.push('/devices/add'),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: AppColors.slate900.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < devices.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.slate100),
                  _buildDeviceRow(devices[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceRow(DeviceModel device) {
    return InkWell(
      onTap: () => context.push('/devices'),
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smartphone_rounded,
                  color: AppColors.slate500, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800),
                  ),
                  Text(
                    device.isOnline ? 'Đang hoạt động' : 'Ngoại tuyến',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: device.isOnline
                          ? AppColors.emerald400
                          : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: device.isOnline
                    ? AppColors.emerald400
                    : AppColors.slate200,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.slate400),
            const SizedBox(height: 8),
            Text(title,
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500)),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 12, color: AppColors.slate400)),
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
    navigatorKey: navigatorKey,
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
          GoRoute(
            path: ':id/time-limit',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return TimeLimitScreen(profileId: id, profileName: name);
            },
          ),
          GoRoute(
            path: ':id/app-blocking',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return AppBlockingScreen(profileId: id, profileName: name);
            },
          ),
          GoRoute(
            path: ':id/app-usage',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return AppUsageReportScreen(profileId: id, profileName: name);
            },
          ),
          GoRoute(
            path: ':id/location',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return MapScreen(profileId: id, profileName: name);
            },
          ),
          GoRoute(
            path: ':id/location-history',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return LocationHistoryScreen(profileId: id, profileName: name);
            },
          ),
          GoRoute(
            path: ':id/sos-history',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final name = state.uri.queryParameters['name'] ?? 'Trẻ em';
              return SosHistoryScreen(profileId: id, profileName: name);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/sos-alert',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return SOSAlertScreen(
            profileName: extras['profileName'] ?? 'Bé',
            latitude: (extras['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (extras['longitude'] as num?)?.toDouble() ?? 0.0,
            audioUrl: extras['audioUrl'],
            phone: extras['phone'],
            sosTime: extras['sosTime'],
          );
        },
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
      GoRoute(
        path: '/child-dashboard',
        builder: (context, state) => const ChildDashboardScreen(),
      ),
      GoRoute(
        path: '/child-request-time',
        builder: (context, state) => const ChildRequestTimeScreen(),
      ),
    ],
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isAuthScreen = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isRoleSelection = state.matchedLocation == '/role-selection';

      if (authState is AuthLoading || roleState.isLoading) {
        // Không redirect khỏi auth screens khi đang loading —
        // nếu không LoginScreen sẽ bị unmount và mất state error
        if (isAuthScreen) return null;
        return isSplash ? null : '/splash';
      }

      final roleData = roleState.valueOrNull;
      final role = roleData?.role;
      final isLinked = roleData?.isLinked ?? false;

      // 1. Check Role Selection
      if (role == null) {
        return isRoleSelection ? null : '/role-selection';
      }

      // 2. Child Role bypasses Login and gets forced to scan UI
      if (role == 'child') {
        if (isLinked) {
          // Whitelist all valid child routes to prevent redirect loops
          final isChildRoute = state.matchedLocation == '/child-dashboard' ||
              state.matchedLocation == '/child-request-time';
          if (!isChildRoute) {
            return '/child-dashboard';
          }
        } else {
          if (!state.matchedLocation.startsWith('/devices/scan')) {
            return '/devices/scan';
          }
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

    return TimeExtensionListener(
      navigatorKey: navigatorKey,
      child: MaterialApp.router(
        title: 'KidFun',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
