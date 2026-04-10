import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/profile_provider.dart';
import '../../../shared/models/profile_model.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class ProfileListScreen extends ConsumerStatefulWidget {
  const ProfileListScreen({super.key});

  @override
  ConsumerState<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends ConsumerState<ProfileListScreen> {
  @override
  void initState() {
    super.initState();
    _listenForSOS();
  }

  void _listenForSOS() {
    SocketService.instance.socket.on('sosAlert', (data) {
      if (!mounted) return;
      
      final profileName = data['profileName'] as String?;
      final lat = data['latitude'] as num?;
      final lng = data['longitude'] as num?;
      final audioUrl = data['audioUrl'] as String?;
      final sosTime = data['timestamp']?.toString(); // ISO 8601 from server
      
      context.push('/sos-alert', extra: {
        'profileName': profileName,
        'latitude': lat,
        'longitude': lng,
        'audioUrl': audioUrl,
        'phone': null,
        'sosTime': sosTime,
      });
    });
  }

  @override
  void dispose() {
    SocketService.instance.socket.off('sosAlert');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Hồ sơ các bé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Thêm hồ sơ',
            onPressed: () => context.push('/profiles/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(profileProvider.notifier).fetchProfiles(),
        color: AppColors.indigo600,
        child: _buildBody(context, state, ref),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ProfileState state, WidgetRef ref) {
    if (state is ProfileLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600));
    }

    if (state is ProfileError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(state.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      color: AppColors.danger, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    ref.read(profileProvider.notifier).fetchProfiles(),
                child: Text('Thử lại',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    if (state is ProfileLoaded) {
      if (state.profiles.isEmpty) {
        return ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.requestBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.child_care_rounded,
                            size: 40, color: AppColors.indigo600),
                      ),
                      const SizedBox(height: 16),
                      Text('Chưa có hồ sơ nào',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800)),
                      const SizedBox(height: 8),
                      Text(
                        'Thêm hồ sơ cho con để bắt đầu\nquản lý thời gian và nội dung',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/profiles/create'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Thêm hồ sơ đầu tiên',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        itemCount: state.profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildProfileCard(context, state.profiles[index]),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProfileCard(BuildContext context, ProfileModel profile) {
    final initials =
        profile.profileName.isNotEmpty ? profile.profileName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () =>
          context.push('/profiles/${profile.id}/edit', extra: profile),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.profileName,
                    style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (profile.age != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.requestBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${profile.age} tuổi',
                            style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.indigo600),
                          ),
                        ),
                      ] else ...[
                        Text('Chưa cập nhật ngày sinh',
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: AppColors.slate400)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate400, size: 22),
          ],
        ),
      ),
    );
  }
}
