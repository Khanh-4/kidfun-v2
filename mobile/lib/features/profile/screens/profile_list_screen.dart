import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';

class ProfileListScreen extends ConsumerWidget {
  const ProfileListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ con'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/profiles/create'),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(profileProvider.notifier).fetchProfiles();
        },
        child: _buildBody(context, state, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProfileState state, WidgetRef ref) {
    if (state is ProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state is ProfileError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(profileProvider.notifier).fetchProfiles(),
              child: const Text('Thử lại'),
            )
          ],
        ),
      );
    }

    if (state is ProfileLoaded) {
      if (state.profiles.isEmpty) {
        return ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: const Center(
                child: Text('Chưa có hồ sơ nào. Nhấn + để thêm.'),
              ),
            )
          ],
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.profiles.length,
        itemBuilder: (context, index) {
          final profile = state.profiles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.child_care, color: Colors.blue),
              ),
              title: Text(profile.profileName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(profile.age != null ? '${profile.age} tuổi' : 'Chưa định thông tin tuổi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profiles/${profile.id}/edit', extra: profile),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
