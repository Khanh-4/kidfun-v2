import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isNotEmpty && password.isNotEmpty) {
      await ref.read(authProvider.notifier).login(email, password);
      if (mounted && ref.read(authProvider) is AuthAuthenticated) {
        context.go('/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ email và mật khẩu')),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    final missingPhoneNumber = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;

    if (ref.read(authProvider) is AuthAuthenticated) {
      if (missingPhoneNumber) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => _PhonePromptSheet(),
        );
      }
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              _buildFormCard(isLoading, errorMessage),
              _buildFooterLinks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.linkDeviceGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo600.withOpacity(0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.shield_outlined, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'KidFun',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
          ),
        ),
        Text(
          'Bảo vệ con yêu của bạn',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFormCard(bool isLoading, String? errorMessage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đăng nhập',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chào mừng trở lại!',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null) ...[
            _buildErrorBanner(errorMessage),
            const SizedBox(height: 16),
          ],
          _buildLabel('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slate400, size: 20),
              hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('Mật khẩu'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slate400, size: 20),
              hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.slate400,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: AppTheme.btnHeightLg,
            child: ElevatedButton(
              onPressed: isLoading ? null : _login,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Đăng nhập',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.slate200)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Hoặc', style: GoogleFonts.nunito(color: AppColors.slate400, fontSize: 13)),
              ),
              const Expanded(child: Divider(color: AppColors.slate200)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: AppTheme.btnHeightLg,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : _loginWithGoogle,
              icon: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
              ),
              label: Text(
                'Đăng nhập bằng Google',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.slate200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.push('/forgot-password'),
          child: Text(
            'Quên mật khẩu?',
            style: GoogleFonts.nunito(
              color: AppColors.indigo600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            'Chưa có tài khoản? Đăng ký ngay',
            style: GoogleFonts.nunito(color: AppColors.slate500, fontSize: 13),
          ),
        ),
        const Divider(height: 32, color: AppColors.slate200),
        TextButton.icon(
          onPressed: () => ref.read(roleProvider.notifier).clearRole(),
          icon: const Icon(Icons.swap_horiz, color: AppColors.slate400, size: 18),
          label: Text(
            'Đổi vai trò',
            style: GoogleFonts.nunito(color: AppColors.slate400, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.slate700,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonePromptSheet extends StatefulWidget {
  @override
  __PhonePromptSheetState createState() => __PhonePromptSheetState();
}

class __PhonePromptSheetState extends State<_PhonePromptSheet> {
  final _phoneController = TextEditingController();

  void _submit() async {
    // We could add update phone API, but for now we just close or call an API.
    // Logic cập nhật số điện thoại sẽ được tích hợp với API Profile ở đây.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bổ sung số điện thoại',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm số điện thoại để bảo mật tài khoản và hỗ trợ phục hồi dễ dàng hơn.',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.slate500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Nhập số điện thoại (Không bắt buộc)',
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.slate400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cập nhật', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bỏ qua', style: GoogleFonts.nunito(fontSize: 14, color: AppColors.slate500)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
