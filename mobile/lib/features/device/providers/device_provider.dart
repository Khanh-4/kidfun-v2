import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_repository.dart';
import '../../../shared/models/device_model.dart';
import '../../../core/network/realtime_service.dart';

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier();
});

// States
sealed class DeviceState {}
class DeviceLoading extends DeviceState {}
class DeviceLoaded extends DeviceState {
  final List<DeviceModel> devices;
  DeviceLoaded(this.devices);
}
class DeviceError extends DeviceState {
  final String message;
  DeviceError(this.message);
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final _repo = DeviceRepository();

  // notify-then-refetch: payload không mang field cụ thể (deviceId/isOnline),
  // nên bất kỳ thay đổi nào trên Device table đều refetch toàn bộ danh sách.
  late final RealtimeCallback _onDeviceChangedRealtime;

  DeviceNotifier() : super(DeviceLoading()) {
    _setupRealtimeListeners();
    fetchDevices();
  }

  void _setupRealtimeListeners() {
    print('🔌 [DeviceProvider] Setting up Realtime (Supabase) listeners');

    _onDeviceChangedRealtime = (data) {
      print('📱 [DeviceProvider][Realtime] Device table changed: $data. Refreshing list...');
      fetchDevices();
    };

    RealtimeService.instance.addDeviceLinkedListener(_onDeviceChangedRealtime);
    RealtimeService.instance.addDeviceOnlineListener(_onDeviceChangedRealtime);
    RealtimeService.instance.addDeviceOfflineListener(_onDeviceChangedRealtime);
  }

  Future<void> fetchDevices() async {
    // Silent loading if we already have data
    final bool isSilent = state is DeviceLoaded;
    if (!isSilent) state = DeviceLoading();

    try {
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
    } catch (e) {
      if (!isSilent) state = DeviceError(e.toString());
    }
  }

  // --- Wrapper methods for UI ---

  Future<void> createDevice(String name, {int? profileId}) async {
    try {
      await _repo.createDevice(name, profileId: profileId);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> assignProfile(int deviceId, int profileId) async {
    try {
      await _repo.assignProfile(deviceId, profileId);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteDevice(int id) async {
    try {
      await _repo.deleteDevice(id);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> linkDevice(String pairingCode) async {
    await _repo.linkDevice(pairingCode);
    await fetchDevices();
  }

  Future<({String code, DateTime expiresAt})> generatePairingCode(
      int profileId) {
    return _repo.generatePairingCode(profileId);
  }

  @override
  void dispose() {
    print('🔌 [DeviceProvider] Removing Realtime listeners');
    RealtimeService.instance.removeDeviceLinkedListener(_onDeviceChangedRealtime);
    RealtimeService.instance.removeDeviceOnlineListener(_onDeviceChangedRealtime);
    RealtimeService.instance.removeDeviceOfflineListener(_onDeviceChangedRealtime);
    super.dispose();
  }
}
