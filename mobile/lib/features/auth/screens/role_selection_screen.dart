import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/role_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBg(AppColors.linkDeviceGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBranding(),
                _buildParentCard(ref),
                const SizedBox(height: 16),
                _buildChildCard(ref),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        const SizedBox(height: 64),
        Container(
          width: 80,
          height: 80,
          decoration: AppTheme.glassCard(radius: 20),
          child: const Icon(Icons.shield_outlined, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'KidShield',
          style: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bảo vệ con yêu của bạn',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Colors.white.withOpacity(0.70),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildParentCard(WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(roleProvider.notifier).setRole('parent'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.indigo600.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
              ),
              child: const Icon(
                Icons.supervisor_account_outlined,
                size: 32,
                color: AppColors.indigo600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tôi là Phụ huynh',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quản lý thời gian và nội dung của con',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(roleProvider.notifier).setRole('child'),
      child: Container(
        decoration: AppTheme.glassCard(),
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
              ),
              child: const Icon(
                Icons.phone_android_outlined,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thiết bị của con',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kết nối thiết bị này với tài khoản phụ huynh',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.70),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.60)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Text(
        'KidShield — Bảo vệ thế hệ tương lai 🛡️',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Colors.white.withOpacity(0.40),
        ),
      ),
    );
  }
}
