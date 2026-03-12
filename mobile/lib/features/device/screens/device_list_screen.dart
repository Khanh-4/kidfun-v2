import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/device_provider.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thiết bị'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(deviceProvider.notifier).fetchDevices();
        },
        child: _buildBody(context, state, ref),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: const Text('Tạo mã QR (Cho máy phụ huynh)'),
                      onTap: () {
                        context.pop();
                        context.push('/devices/add');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner),
                      title: const Text('Quét mã QR (Cho máy trẻ em)'),
                      onTap: () {
                        context.pop();
                        context.push('/devices/scan');
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, DeviceState state, WidgetRef ref) {
    if (state is DeviceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is DeviceError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(deviceProvider.notifier).fetchDevices(),
              child: const Text('Thử lại'),
            )
          ],
        ),
      );
    }

    if (state is DeviceLoaded) {
      if (state.devices.isEmpty) {
        return ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: const Center(
                child: Text('Chưa có thiết bị nào. Nhấn + để thêm.'),
              ),
            )
          ],
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.devices.length,
        itemBuilder: (context, index) {
          final device = state.devices[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.phone_android, color: Colors.blue),
              ),
              title: Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('ID: ${device.deviceIdentifier}\nTrạng thái: ${device.status}'),
              isThreeLine: true,
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
