import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/device_provider.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    final code = barcode.rawValue;
    if (code == null || code.isEmpty) return;

    _processPairingCode(code);
  }

  Future<void> _processPairingCode(String code) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    // Stop scanning once detected
    _controller.stop();

    try {
      // Pass only pairing_code, device info is grabbed in repository
      await ref.read(deviceProvider.notifier).linkDevice(code);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liên kết thiết bị thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
        _controller.start();
      }
    }
  }

  void _showManualEntryDialog() {
    final TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập mã thủ công'),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Nhập mã 6 số',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim();
                if (code.length == 6) {
                  Navigator.of(context).pop();
                  _processPairingCode(code);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đủ 6 số')),
                  );
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  const Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Căn chỉnh mã QR vào trong khung',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        label: const Text(
                          'Nhập mã thủ công',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}
