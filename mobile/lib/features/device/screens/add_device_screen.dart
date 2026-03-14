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

  @override
  void initState() {
    super.initState();
    // Listen for deviceOnline Socket event — na navigate back when child successfully links
    SocketService.instance.addDeviceOnlineListener(_onDeviceOnline);
  }

  void _onDeviceOnline(Map<String, dynamic> data) {
    if (mounted && _pairingCode != null) {
      // Refresh device list and go back
      ref.read(deviceProvider.notifier).fetchDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 Thiết bị "${data['deviceName'] ?? 'mới'}" đã kết nối!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    // Remove the callback so we don't leak or trigger unexpectedly
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
      appBar: AppBar(title: const Text('Tạo mã QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chọn một hồ sơ (trẻ em) để liên kết thiết bị này, sau đó mã QR sẽ được tạo.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              if (profileState is ProfileLoading)
                const Center(child: CircularProgressIndicator()),
                
              if (profileState is ProfileError)
                Text(profileState.message, style: const TextStyle(color: Colors.red)),
                
              if (profileState is ProfileLoaded)
                DropdownButtonFormField<ProfileModel>(
                  decoration: const InputDecoration(labelText: 'Chọn hồ sơ'),
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
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_selectedProfile == null || _isLoading) ? null : _generateCode,
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Tạo mã QR'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],

              if (_pairingCode != null) ...[
                const SizedBox(height: 48),
                const Text(
                  'Sử dụng ứng dụng ở máy trẻ em để quét mã QR này',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Center(
                  child: QrImageView(
                    data: _pairingCode!,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Hoặc nhập mã số này trên máy của trẻ:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _pairingCode!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8.0,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
