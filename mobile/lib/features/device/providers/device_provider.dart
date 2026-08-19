import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_repository.dart';
import '../../../shared/models/device_model.dart';
import '../../../core/network/socket_service.dart';
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
  final List<Map<String, dynamic>> _pendingUpdates = [];

  // Keep references for proper cleanup
  late final SocketCallback _onDeviceLinked;
  late final SocketCallback _onDeviceOnline;
  late final SocketCallback _onDeviceOffline;

  // Realtime (Supabase) — chạy song song SocketService, KHÔNG thay thế, cho
  // tới khi xác nhận Realtime hoạt động ổn định trên thiết bị thật. Payload
  // không có field (notify-then-refetch) nên luôn refetch toàn bộ.
  late final RealtimeCallback _onDeviceChangedRealtime;

  DeviceNotifier() : super(DeviceLoading()) {
    _setupSocketListeners();
    _setupRealtimeListeners();
    fetchDevices();
  }

  void _setupSocketListeners() {
    print('🔌 [DeviceProvider] Setting up Socket listeners');

    _onDeviceLinked = (data) {
      print('📱 [DeviceProvider] RECEIVED deviceLinked: $data. Refreshing list...');
      fetchDevices();
    };

    _onDeviceOnline = (data) {
      print('📱 [DeviceProvider] RECEIVED deviceOnline: $data');
      final rawId = data['deviceId'];
      final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (deviceId != null) {
        _updateDeviceStatus(deviceId, true);
      }
    };

    _onDeviceOffline = (data) {
      print('📱 [DeviceProvider] RECEIVED deviceOffline: $data');
      final rawId = data['deviceId'];
      final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (deviceId != null) {
        _updateDeviceStatus(deviceId, false);
      }
    };

    // ★ Use list-based listeners (supports multiple subscribers)
    SocketService.instance.addDeviceLinkedListener(_onDeviceLinked);
    SocketService.instance.addDeviceOnlineListener(_onDeviceOnline);
    SocketService.instance.addDeviceOfflineListener(_onDeviceOffline);
  }

  void _setupRealtimeListeners() {
    print('🔌 [DeviceProvider] Setting up Realtime (Supabase) listeners — dual-run');

    _onDeviceChangedRealtime = (data) {
      print('📱 [DeviceProvider][Realtime] Device table changed: $data. Refreshing list...');
      fetchDevices();
    };

    RealtimeService.instance.addDeviceLinkedListener(_onDeviceChangedRealtime);
    RealtimeService.instance.addDeviceOnlineListener(_onDeviceChangedRealtime);
    RealtimeService.instance.addDeviceOfflineListener(_onDeviceChangedRealtime);
  }

  void _updateDeviceStatus(int deviceId, bool isOnline) {
    if (state is DeviceLoaded) {
      final devices = (state as DeviceLoaded).devices;

      bool found = false;
      final updated = devices.map((d) {
        if (d.id == deviceId) {
          found = true;
          return d.copyWith(isOnline: isOnline, lastSeen: DateTime.now());
        }
        return d;
      }).toList();

      if (found) {
        state = DeviceLoaded(updated);
        print('✅ [DeviceProvider] Updated device $deviceId to ${isOnline ? "Online" : "Offline"}');
      } else {
        print('⚠️ [DeviceProvider] Device $deviceId not found in current list. Will refresh.');
        fetchDevices();
      }
    } else {
      // If still loading, queue the update
      _pendingUpdates.add({'deviceId': deviceId, 'isOnline': isOnline});
    }
  }

  void _applyPendingUpdates() {
    if (_pendingUpdates.isEmpty || state is! DeviceLoaded) return;

    final devices = (state as DeviceLoaded).devices;
    var updatedDevices = List<DeviceModel>.from(devices);

    for (var update in _pendingUpdates) {
      final id = update['deviceId'] as int;
      final online = update['isOnline'] as bool;
      updatedDevices = updatedDevices
          .map((d) => d.id == id ? d.copyWith(isOnline: online, lastSeen: DateTime.now()) : d)
          .toList();
    }

    _pendingUpdates.clear();
    state = DeviceLoaded(updatedDevices);
  }

  Future<void> fetchDevices() async {
    // Silent loading if we already have data
    final bool isSilent = state is DeviceLoaded;
    if (!isSilent) state = DeviceLoading();

    try {
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
      _applyPendingUpdates();
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
    try {
      await _repo.linkDevice(pairingCode);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<String> generatePairingCode(int profileId) async {
    try {
      return await _repo.generatePairingCode(profileId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  void dispose() {
    print('🔌 [DeviceProvider] Removing Socket + Realtime listeners');
    SocketService.instance.removeDeviceLinkedListener(_onDeviceLinked);
    SocketService.instance.removeDeviceOnlineListener(_onDeviceOnline);
    SocketService.instance.removeDeviceOfflineListener(_onDeviceOffline);
    RealtimeService.instance.removeDeviceLinkedListener(_onDeviceChangedRealtime);
    RealtimeService.instance.removeDeviceOnlineListener(_onDeviceChangedRealtime);
    RealtimeService.instance.removeDeviceOfflineListener(_onDeviceChangedRealtime);
    super.dispose();
  }
}
