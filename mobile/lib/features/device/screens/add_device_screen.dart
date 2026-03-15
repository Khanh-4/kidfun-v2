import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/device_provider.dart';
import '../../../shared/models/profile_model.dart';
import '../../../core/network/socket_service.dart';

class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  ProfileModel? _selectedProfile;
  String? _pairingCode;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSocketConnected = false;

  @override
  void initState() {
    super.initState();
    // Listen for deviceOnline Socket event
    SocketService.instance.addDeviceOnlineListener(_onDeviceOnline);
    _checkSocketStatus();
  }

  void _checkSocketStatus() {
    setState(() {
      _isSocketConnected = SocketService.instance.isConnected;
    });
    
    if (!_isSocketConnected) {
      print('📡 [AddDeviceScreen] Socket disconnected. Reconnecting...');
      SocketService.instance.reconnect();
    }
  }

  void _onDeviceOnline(Map<String, dynamic> data) {
    if (!mounted) return;
    
    print('📱 [AddDeviceScreen] TRIGGERED!! Nhận deviceOnline: $data');

    // Chấp nhận bất kỳ thiết bị nào mới online lúc này
    if (_pairingCode != null) {
      print('🚀 [AddDeviceScreen] Kích hoạt thành công mang tên: ${data['deviceName']}');
      
      // Refresh danh sách thiết bị
      ref.read(deviceProvider.notifier).fetchDevices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã kết nối thiết bị "${data['deviceName']}"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Chuyển về màn hình danh sách sau 500ms để người dùng kịp thấy SnackBar thành công
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.pop();
      });
    }
  }

  @override
  void dispose() {
    print('📡 [AddDeviceScreen] Disposing screen and removing listener');
    SocketService.instance.removeDeviceOnlineListener(_onDeviceOnline);
    super.dispose();
  }

  void _generateCode() async {
    if (_selectedProfile == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pairingCode = null;
    });

    try {
      final code = await ref.read(deviceProvider.notifier).generatePairingCode(_selectedProfile!.id);
      
      if (mounted) {
        setState(() {
          _pairingCode = code;
          _isLoading = false;
        });
        print('📶 [AddDeviceScreen] Pairing code: $code. Chờ sự kiện deviceOnline...');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    _isSocketConnected = SocketService.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kích hoạt máy con'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _isSocketConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isSocketConnected ? Colors.green : Colors.red),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isSocketConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isSocketConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isSocketConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quét mã này bằng ứng dụng KidFun trên máy của trẻ để bắt đầu quản lý.',
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              if (profileState is ProfileLoaded)
                DropdownButtonFormField<ProfileModel>(
                  decoration: const InputDecoration(
                    labelText: 'Chọn hồ sơ của trẻ',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedProfile,
                  items: profileState.profiles.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.profileName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProfile = val;
                      _pairingCode = null;
                    });
                  },
                )
              else if (profileState is ProfileLoading)
                const Center(child: CircularProgressIndicator())
              else
                const Text('Lỗi tải hồ sơ hoặc chưa có hồ sơ nào.', textAlign: TextAlign.center),

              const SizedBox(height: 48),
              if (_pairingCode == null)
                ElevatedButton(
                  onPressed: (_selectedProfile == null || _isLoading) ? null : _generateCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('TẠO MÃ KẾT NỐI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],

              if (_pairingCode != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'ĐANG ĐỢI TRẺ QUÉT MÃ...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                      ],
                    ),
                    child: QrImageView(
                      data: _pairingCode!,
                      version: QrVersions.auto,
                      size: 220.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _pairingCode!,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Hủy bỏ'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
