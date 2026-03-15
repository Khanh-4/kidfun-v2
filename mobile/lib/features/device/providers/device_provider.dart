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
  final List<Map<String, dynamic>> _pendingUpdates = [];

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
      print('⏳ [DeviceProvider] State is ${state.runtimeType}. Queuing update for device $deviceId as ${isOnline ? 'ONLINE' : 'OFFLINE'}');
      _pendingUpdates.add({'deviceId': deviceId, 'isOnline': isOnline});
    }
  }

  void _applyPendingUpdates() {
    if (_pendingUpdates.isEmpty || state is! DeviceLoaded) return;
    
    print('🔄 [DeviceProvider] Applying ${_pendingUpdates.length} pending socket updates');
    final devices = (state as DeviceLoaded).devices;
    var updatedDevices = List<DeviceModel>.from(devices);
    
    for (var update in _pendingUpdates) {
      final id = update['deviceId'] as int;
      final online = update['isOnline'] as bool;
      
      updatedDevices = updatedDevices.map((d) {
        if (d.id == id) {
          return d.copyWith(isOnline: online, lastSeen: DateTime.now());
        }
        return d;
      }).toList();
    }
    
    _pendingUpdates.clear();
    state = DeviceLoaded(updatedDevices);
  }

  Future<void> fetchDevices() async {
    // Chỉ hiện loading nếu chưa có dữ liệu. Nếu đã có thì refresh ngầm.
    final bool isSilent = state is DeviceLoaded;
    if (!isSilent) {
      state = DeviceLoading();
    }
    
    try {
      print('📡 [DeviceProvider] Fetching devices from API...');
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
      print('✅ [DeviceProvider] Fetched ${devices.length} devices');
      
      // Áp dụng các cập nhật socket nhận được trong lúc đang loading
      _applyPendingUpdates();
    } catch (e) {
      print('❌ [DeviceProvider] fetchDevices error: $e');
      if (!isSilent) {
        state = DeviceError(e.toString().replaceAll('Exception: ', ''));
      }
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
