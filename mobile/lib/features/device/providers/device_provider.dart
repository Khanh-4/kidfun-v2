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
    print('🔌 DeviceProvider: Setting up Socket.IO listeners...');
    
    SocketService.instance.addDeviceOnlineListener((data) {
      print('📱 Socket Event: deviceOnline -> $data');
      final rawId = data['deviceId'];
      final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      print('📱 Parsed deviceId: $deviceId');
      if (deviceId != null) _updateDeviceStatus(deviceId, true);
    });

    SocketService.instance.addDeviceOfflineListener((data) {
      print('📱 Socket Event: deviceOffline -> $data');
      final rawId = data['deviceId'];
      final deviceId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      print('📱 Parsed deviceId: $deviceId');
      if (deviceId != null) _updateDeviceStatus(deviceId, false);
    });
  }

  void _updateDeviceStatus(int deviceId, bool isOnline) {
    print('🔄 _updateDeviceStatus: deviceId=$deviceId, isOnline=$isOnline');
    print('🔄 Current UI state: ${state.runtimeType}');
    
    if (state is DeviceLoaded) {
      final devices = (state as DeviceLoaded).devices;
      print('🔄 Devices in list: ${devices.map((d) => d.id).toList()}');
      
      final updated = devices.map((d) {
        if (d.id == deviceId) {
          print('✅ MATCH FOUND for device $deviceId. Updating to $isOnline');
          return d.copyWith(isOnline: isOnline, lastSeen: DateTime.now());
        }
        return d;
      }).toList();
      
      // Only update state if something actually changed
      final changed = updated.any((d) => d.id == deviceId && d.isOnline == isOnline);
      print('🔄 State changed: $changed');
      if (changed) {
        state = DeviceLoaded(updated);
        print('✨ State updated with new device list');
      }
    }
  }

  Future<void> fetchDevices() async {
    state = DeviceLoading();
    try {
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
    } catch (e) {
      state = DeviceError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> createDevice(String name, {int? profileId}) async {
    try {
      await _repo.createDevice(name, profileId: profileId);
      await fetchDevices(); // Refresh list
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
