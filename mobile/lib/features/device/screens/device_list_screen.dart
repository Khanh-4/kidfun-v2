import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/device_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/models/device_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(deviceProvider.notifier).fetchDevices());
  }

  String _formatLastSeen(DeviceModel device) {
    if (device.isOnline || device.lastSeen == null) return '';
    final diff = DateTime.now().difference(device.lastSeen!);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _showDeviceOptions(
      BuildContext context, DeviceModel device, List<ProfileModel> profiles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeviceOptionsSheet(
        device: device,
        profiles: profiles,
        onAssign: (profileId) async {
          Navigator.pop(ctx);
          try {
            await ref
                .read(deviceProvider.notifier)
                .assignProfile(device.id, profileId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Đã cập nhật hồ sơ thiết bị',
                    style: GoogleFonts.nunito()),
                backgroundColor: AppColors.success,
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('Lỗi: $e', style: GoogleFonts.nunito()),
                backgroundColor: AppColors.danger,
              ));
            }
          }
        },
        onTimeLimitTap: device.profileId != null
            ? () {
                Navigator.pop(ctx);
                final profileName = profiles
                    .firstWhere((p) => p.id == device.profileId)
                    .profileName;
                context.push(
                  '/profiles/${device.profileId}/time-limit?name=${Uri.encodeComponent(profileName)}',
                );
              }
            : null,
        onDelete: () async {
          Navigator.pop(ctx);
          try {
            await ref
                .read(deviceProvider.notifier)
                .deleteDevice(device.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Đã xoá thiết bị thành công',
                    style: GoogleFonts.nunito()),
                backgroundColor: AppColors.success,
              ));
            }
          } catch (e) {
            final errStr = e.toString().toLowerCase();
            if (errStr.contains('404') || errStr.contains('not found')) {
              ref.read(deviceProvider.notifier).fetchDevices();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Thiết bị đã bị xoá, đã làm mới.',
                      style: GoogleFonts.nunito()),
                ));
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('Lỗi: $e', style: GoogleFonts.nunito()),
                  backgroundColor: AppColors.danger,
                ));
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceProvider);
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Thiết bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Thêm thiết bị',
            onPressed: () => context.push('/devices/add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(deviceProvider.notifier).fetchDevices(),
        color: AppColors.indigo600,
        child: _buildBody(context, state, profileState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DeviceState state,
      ProfileState profileState) {
    if (state is DeviceLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600));
    }

    if (state is DeviceError) {
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
                    ref.read(deviceProvider.notifier).fetchDevices(),
                child: Text('Thử lại',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    if (state is DeviceLoaded) {
      final profiles = profileState is ProfileLoaded
          ? profileState.profiles
          : <ProfileModel>[];

      if (state.devices.isEmpty) {
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
                        decoration: const BoxDecoration(
                          color: AppColors.requestBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.devices_rounded,
                            size: 40, color: AppColors.indigo600),
                      ),
                      const SizedBox(height: 16),
                      Text('Chưa có thiết bị nào',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800)),
                      const SizedBox(height: 8),
                      Text(
                        'Thêm thiết bị con để bắt đầu\ngiám sát và kiểm soát',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/devices/add'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Thêm thiết bị đầu tiên',
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
        itemCount: state.devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final device = state.devices[index];
          final profileName = profiles
              .where((p) => p.id == device.profileId)
              .map((p) => p.profileName)
              .firstOrNull;
          final lastSeen = _formatLastSeen(device);
          return _buildDeviceCard(
              context, device, profileName, lastSeen, profiles);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDeviceCard(
    BuildContext context,
    DeviceModel device,
    String? profileName,
    String lastSeen,
    List<ProfileModel> profiles,
  ) {
    return GestureDetector(
      onTap: () => _showDeviceOptions(context, device, profiles),
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
            // Device icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: device.isOnline
                    ? AppColors.requestBg
                    : AppColors.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.smartphone_rounded,
                color: device.isOnline
                    ? AppColors.indigo600
                    : AppColors.slate400,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Online status dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: device.isOnline
                              ? AppColors.emerald400
                              : AppColors.slate400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.isOnline
                            ? 'Đang hoạt động'
                            : (lastSeen.isNotEmpty
                                ? 'Offline · $lastSeen'
                                : 'Ngoại tuyến'),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: device.isOnline
                              ? AppColors.emerald400
                              : AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  if (profileName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(
                          profileName,
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert_rounded,
                color: AppColors.slate400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet Widget ───────────────────────────────────────────────────────

class _DeviceOptionsSheet extends StatefulWidget {
  final DeviceModel device;
  final List<ProfileModel> profiles;
  final Future<void> Function(int profileId) onAssign;
  final VoidCallback? onTimeLimitTap;
  final Future<void> Function() onDelete;

  const _DeviceOptionsSheet({
    required this.device,
    required this.profiles,
    required this.onAssign,
    required this.onTimeLimitTap,
    required this.onDelete,
  });

  @override
  State<_DeviceOptionsSheet> createState() => _DeviceOptionsSheetState();
}

class _DeviceOptionsSheetState extends State<_DeviceOptionsSheet> {
  late int? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.profiles.any((p) => p.id == widget.device.profileId)
        ? widget.device.profileId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Device header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.device.isOnline
                      ? AppColors.requestBg
                      : AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.smartphone_rounded,
                  color: widget.device.isOnline
                      ? AppColors.indigo600
                      : AppColors.slate400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.device.deviceName,
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: widget.device.isOnline
                                ? AppColors.emerald400
                                : AppColors.slate400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.device.isOnline
                              ? 'Đang hoạt động'
                              : 'Ngoại tuyến',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: widget.device.isOnline
                                ? AppColors.emerald400
                                : AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 16),
          // Profile assignment
          Text('Gán hồ sơ',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500)),
          const SizedBox(height: 8),
          if (widget.profiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Text(
                'Chưa có hồ sơ nào. Hãy tạo hồ sơ cho con trước.',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.warning),
              ),
            )
          else
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                hintText: 'Chọn hồ sơ',
                hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
                prefixIcon: const Icon(Icons.person_outline,
                    color: AppColors.slate400, size: 20),
              ),
              initialValue: _selectedProfileId,
              items: widget.profiles
                  .map((p) => DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(p.profileName,
                            style: GoogleFonts.nunito(
                                fontSize: 14, color: AppColors.slate800)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedProfileId = val);
                  widget.onAssign(val);
                }
              },
            ),
          if (widget.onTimeLimitTap != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onTimeLimitTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.indigo600,
                side: const BorderSide(color: AppColors.indigo600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
                minimumSize: const Size.fromHeight(AppTheme.btnHeightSm),
              ),
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: Text('Giới hạn thời gian',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 12),
          SizedBox(
            height: AppTheme.btnHeightSm,
            child: ElevatedButton.icon(
              onPressed: widget.onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
              ),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 18),
              label: Text('Xóa thiết bị',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
