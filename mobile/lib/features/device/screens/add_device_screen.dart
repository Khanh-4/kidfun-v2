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
  bool _isLinked = false;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Check connection
    _isSocketConnected = SocketService.instance.isConnected;
    if (!_isSocketConnected) {
      SocketService.instance.reconnect();
    }

    // ★ Listen for deviceLinked event as per Sprint document
    SocketService.instance.onDeviceLinkedCallback = (data) {
      _handleSuccessfulLink(data);
    };

    // Fallback: also listen for deviceOnline just in case
    SocketService.instance.addDeviceOnlineListener(_handleSuccessfulLink);
  }

  void _handleSuccessfulLink(Map<String, dynamic> data) {
    if (!mounted || _isLinked) return;
    
    print('🚀 [AddDeviceScreen] Success! Device linked/online: $data');

    if (_pairingCode != null) {
      setState(() => _isLinked = true);
      
      // Refresh device list
      ref.read(deviceProvider.notifier).fetchDevices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Thiết bị "${data['deviceName']}" đã kết nối thành công!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Auto-navigate to Device List after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          context.pop();
        }
      });
    }
  }

  @override
  void dispose() {
    print('📡 [AddDeviceScreen] Cleaning up listeners');
    SocketService.instance.onDeviceLinkedCallback = null;
    SocketService.instance.removeDeviceOnlineListener(_handleSuccessfulLink);
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
        print('📶 [AddDeviceScreen] Pairing code generated: $code');
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
        title: const Text('Thêm thiết bị con'),
        actions: [
          _buildConnectionIndicator(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLinked) _buildSuccessState() else _buildInputState(profileState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
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
            width: 8, height: 8,
            decoration: BoxDecoration(color: _isSocketConnected ? Colors.green : Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(_isSocketConnected ? 'Sẵn sàng' : 'Mất kết nối', style: TextStyle(color: _isSocketConnected ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.check_circle, color: Colors.green, size: 100),
        const SizedBox(height: 24),
        const Text('KÍCH HOẠT THÀNH CÔNG!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 16),
        const Text('Đang quay lại danh sách thiết bị...', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildInputState(ProfileState profileState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. Chọn hồ sơ của trẻ\n2. Dùng máy trẻ quét mã QR bên dưới',
          style: TextStyle(fontSize: 16, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        
        if (profileState is ProfileLoaded)
          DropdownButtonFormField<ProfileModel>(
            decoration: const InputDecoration(labelText: 'Hồ sơ trẻ em', border: OutlineInputBorder()),
            value: _selectedProfile,
            items: profileState.profiles.map((p) => DropdownMenuItem(value: p, child: Text(p.profileName))).toList(),
            onChanged: (val) => setState(() { _selectedProfile = val; _pairingCode = null; }),
          )
        else if (profileState is ProfileLoading)
          const Center(child: CircularProgressIndicator())
        else
          const Text('Vui lòng tạo hồ sơ cho trẻ trước.', textAlign: TextAlign.center),

        const SizedBox(height: 40),
        
        if (_pairingCode == null)
          ElevatedButton(
            onPressed: (_selectedProfile == null || _isLoading) ? null : _generateCode,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('TẠO MÃ KẾT NỐI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ],

        if (_pairingCode != null) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 24),
          const Text('ĐANG CHỜ KẾT NỐI...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
              child: QrImageView(data: _pairingCode!, version: QrVersions.auto, size: 200.0),
            ),
          ),
          const SizedBox(height: 24),
          Text(_pairingCode!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.blue), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          OutlinedButton(onPressed: () => context.pop(), child: const Text('Quay lại')),
        ],
      ],
    );
  }
}
