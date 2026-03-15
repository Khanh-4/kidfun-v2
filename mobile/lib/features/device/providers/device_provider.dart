import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_repository.dart';
import '../../../shared/models/device_model.dart';
import '../../../core/network/socket_service.dart';

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

  DeviceNotifier() : super(DeviceLoading()) {
    _setupSocketListeners();
    fetchDevices();
  }

  void _setupSocketListeners() {
    print('🔌 [DeviceProvider] Initializing Socket listeners');
    
    // Use the multi-listener support in SocketService
    SocketService.instance.addDeviceOnlineListener(_handleDeviceOnline);
    SocketService.instance.addDeviceOfflineListener(_handleDeviceOffline);
  }

  void _handleDeviceOnline(Map<String, dynamic> data) {
    print('📱 [DeviceProvider] RECEIVED deviceOnline: $data');
    final rawId = data['deviceId'];
    final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (deviceId != null) {
      _updateDeviceStatus(deviceId, true);
    }
  }

  void _handleDeviceOffline(Map<String, dynamic> data) {
    print('📱 [DeviceProvider] RECEIVED deviceOffline: $data');
    final rawId = data['deviceId'];
    final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (deviceId != null) {
      _updateDeviceStatus(deviceId, false);
    }
  }

  void _updateDeviceStatus(int deviceId, bool isOnline) {
    if (state is DeviceLoaded) {
      final devices = (state as DeviceLoaded).devices;
      
      bool found = false;
      final updated = devices.map((d) {
        if (d.id == deviceId) {
          found = true;
          if (d.isOnline == isOnline) return d; // No change
          print('✨ [DeviceProvider] Updating device $deviceId to ${isOnline ? 'ONLINE' : 'OFFLINE'}');
          return d.copyWith(isOnline: isOnline, lastSeen: DateTime.now());
        }
        return d;
      }).toList();

      if (found) {
        state = DeviceLoaded(updated);
      } else {
        print('⚠️ [DeviceProvider] Received status for device $deviceId but it is not in the current list');
      }
    } else {
      print('⏳ [DeviceProvider] Received status update but state is not Loaded (${state.runtimeType})');
    }
  }

  Future<void> fetchDevices() async {
    // Only show loading if we don't have data yet
    if (state is! DeviceLoaded) {
      state = DeviceLoading();
    }
    
    try {
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
      print('✅ [DeviceProvider] Fetched ${devices.length} devices');
    } catch (e) {
      state = DeviceError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> createDevice(String name, {int? profileId}) async {
    try {
      await _repo.createDevice(name, profileId: profileId);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> assignProfile(int deviceId, int profileId) async {
    try {
      await _repo.assignProfile(deviceId, profileId);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteDevice(int id) async {
    try {
      await _repo.deleteDevice(id);
      await fetchDevices();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> linkDevice(String pairingCode) async {
    try {
      await _repo.linkDevice(pairingCode);
      await fetchDevices();
    } catch (e) {
      throw Exception((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<String> generatePairingCode(int profileId) async {
    try {
      return await _repo.generatePairingCode(profileId);
    } catch (e) {
      throw Exception((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }
}
