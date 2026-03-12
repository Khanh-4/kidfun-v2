import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/role_provider.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // KidFun Logo / Branding with Hero Animation
              Center(
                child: Hero(
                  tag: 'kidfun_logo',
                  child: Column(
                    children: [
                      Icon(Icons.child_care, size: 100, color: Colors.blue.shade600),
                      const SizedBox(height: 16),
                      Text(
                        'KidFun',
                        style: TextStyle(
                          fontSize: 40, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn đang thiết lập cho thiết bị của ai?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Parent Card
              _RoleCard(
                icon: Icons.supervisor_account,
                title: 'Tôi là Phụ huynh',
                description: 'Quản lý thời gian và nội dung của con',
                color: Colors.blue.shade600,
                onTap: () async {
                  await ref.read(roleProvider.notifier).setRole('parent');
                },
              ),

              const SizedBox(height: 24),

              // Child Card
              _RoleCard(
                icon: Icons.smart_display,
                title: 'Thiết bị của con',
                description: 'Kết nối thiết bị này với tài khoản phụ huynh',
                color: Colors.orange.shade600,
                onTap: () async {
                  await ref.read(roleProvider.notifier).setRole('child');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
