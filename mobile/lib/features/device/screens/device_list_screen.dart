import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/device_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/models/device_model.dart';
import '../../../shared/models/profile_model.dart';

class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial device list when screen opens
    Future.microtask(() => ref.read(deviceProvider.notifier).fetchDevices());
  }

  void _showDeviceOptions(BuildContext context, DeviceModel device, List<ProfileModel> profiles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tùy chọn: ${device.deviceName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text('Gán vào hồ sơ:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  value: profiles.any((p) => p.id == device.profileId) ? device.profileId : null,
                  items: profiles.map((p) {
                    return DropdownMenuItem<int>(
                      value: p.id,
                      child: Text(p.profileName),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      // Close sheet first, then assign
                      Navigator.pop(ctx);
                      try {
                        await ref.read(deviceProvider.notifier).assignProfile(device.id, val);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã cập nhật cấu hình thiết bị')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  hint: const Text('Chọn một hồ sơ'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Close bottom sheet BEFORE calling API to avoid deactivated ancestor crash
                    Navigator.pop(ctx);

                    try {
                      await ref.read(deviceProvider.notifier).deleteDevice(device.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xoá thiết bị thành công'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      final errStr = e.toString().toLowerCase();
                      // If device already deleted (404), just refresh list silently
                      if (errStr.contains('404') || errStr.contains('not found')) {
                        ref.read(deviceProvider.notifier).fetchDevices();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thiết bị đã bị xoá trước đó, đã làm mới danh sách.')),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Xóa thiết bị', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceProvider);
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/devices/add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(deviceProvider.notifier).fetchDevices();
        },
        child: _buildBody(context, state, profileState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DeviceState state, ProfileState profileState) {
    if (state is DeviceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is DeviceError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(deviceProvider.notifier).fetchDevices(),
              child: const Text('Thử lại'),
            )
          ],
        ),
      );
    }

    if (state is DeviceLoaded) {
      if (state.devices.isEmpty) {
        return ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: const Center(
                child: Text(
                  'Chưa có thiết bị nào. Nhấn + để thêm.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          ],
        );
      }

      List<ProfileModel> profiles = [];
      if (profileState is ProfileLoaded) {
        profiles = profileState.profiles;
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.devices.length,
        itemBuilder: (context, index) {
          final device = state.devices[index];

          // Tìm tên profile map
          String profileName = 'Chưa gán';
          if (device.profileId != null) {
            final p = profiles.where((element) => element.id == device.profileId).toList();
            if (p.isNotEmpty) {
              profileName = p.first.profileName;
            }
          }

          // Format lastSeen simple logic
          String lastSeenStr = '';
          if (!device.isOnline && device.lastSeen != null) {
            final diff = DateTime.now().difference(device.lastSeen!);
            if (diff.inMinutes < 60) {
              lastSeenStr = '${diff.inMinutes} phút trước';
            } else if (diff.inHours < 24) {
              lastSeenStr = '${diff.inHours} giờ trước';
            } else {
              lastSeenStr = '${diff.inDays} ngày trước';
            }
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showDeviceOptions(context, device, profiles),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(device.isOnline ? '🟢' : '🔴', style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.deviceName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Profile: $profileName',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 2),
                          if (device.isOnline)
                            const Text('Online', style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w500))
                          else if (lastSeenStr.isNotEmpty)
                            Text('Last seen: $lastSeenStr', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_vert, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
