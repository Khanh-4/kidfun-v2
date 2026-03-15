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
  int? _pendingDeviceId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Listen for deviceOnline Socket event
    SocketService.instance.addDeviceOnlineListener(_onDeviceOnline);
    
    // Đảm bảo Socket đã được kết nối và ở trong phòng gia đình
    if (!SocketService.instance.isConnected) {
      print('📡 [AddDeviceScreen] Socket chưa kết nối. Đang thử kết nối lại...');
      SocketService.instance.reconnect();
    }
  }

  void _onDeviceOnline(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final eventDeviceId = data['deviceId'];
    print('📱 [AddDeviceScreen] Nhận sự kiện deviceOnline từ Socket: $data');
    print('📱 [AddDeviceScreen] Đang chờ DeviceId: $_pendingDeviceId, Event DeviceId: $eventDeviceId');

    // Nếu trùng DeviceId hoặc nếu pairingCode đang bật (chấp nhận bất kỳ thiết bị nào mới online lúc này)
    if (_pairingCode != null) {
      print('🚀 [AddDeviceScreen] Thiết bị mới đã kết nối thành công! Đang chuyển hướng...');
      
      // Refresh danh sách thiết bị
      ref.read(deviceProvider.notifier).fetchDevices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Thiết bị "${data['deviceName'] ?? 'mới'}" đã kích hoạt!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Quay lại màn hình danh sách
      context.pop();
    }
  }

  @override
  void dispose() {
    print('📡 [AddDeviceScreen] Đang đóng màn hình, gỡ listener...');
    SocketService.instance.removeDeviceOnlineListener(_onDeviceOnline);
    super.dispose();
  }

  void _generateCode() async {
    if (_selectedProfile == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pairingCode = null;
      _pendingDeviceId = null;
    });

    try {
      // Gọi repository trực tiếp để lấy deviceId (vì notifier.generatePairingCode chỉ trả về String code)
      // Để tiện, mình sửa lại notifier hoặc repository. Ở đây mình dùng repo của notifier.
      final code = await ref.read(deviceProvider.notifier).generatePairingCode(_selectedProfile!.id);
      
      if (mounted) {
        setState(() {
          _pairingCode = code;
          _isLoading = false;
        });
        print('📶 [AddDeviceScreen] Đã tạo mã pairing: $code. Chờ thiết bị con kết nối...');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thiết bị con')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Chọn hồ sơ của trẻ\n2. Quét mã QR bằng ứng dụng KidFun trên máy của trẻ',
                style: TextStyle(fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              if (profileState is ProfileLoaded)
                DropdownButtonFormField<ProfileModel>(
                  decoration: const InputDecoration(
                    labelText: 'Chọn hồ sơ trẻ em',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
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
                const Text('Không tìm thấy hồ sơ nào. Vui lòng tạo hồ sơ trước.', textAlign: TextAlign.center),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: (_selectedProfile == null || _isLoading) ? null : _generateCode,
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.qr_code),
                label: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('HIỆN MÃ QR KẾT NỐI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],

              if (_pairingCode != null) ...[
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'ĐANG CHỜ KẾT NỐI...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
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
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                    child: QrImageView(
                      data: _pairingCode!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Mã số: $_pairingCode',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Hủy bỏ và quay lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
