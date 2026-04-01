import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email hợp lệ')),
      );
      return;
    }
    ref.read(forgotPasswordProvider.notifier).sendOtp(email);
  }

  void _resetPassword() {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP phải đủ 6 chữ số')),
      );
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải từ 6 ký tự')),
      );
      return;
    }
    ref.read(forgotPasswordProvider.notifier).resetPassword(email, otp, newPassword);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);

    ref.listen<ForgotPasswordState>(forgotPasswordProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger),
        );
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.',
              style: GoogleFonts.nunito(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/login');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(state.isOtpSent),
              _buildFormCard(state),
              _buildFooterLinks(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isOtpSent) {
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
            child: const Icon(Icons.lock_reset_outlined, size: 38, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Quên mật khẩu',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
          ),
        ),
        Text(
          isOtpSent ? 'Nhập mã OTP đã gửi đến email' : 'Nhập email để nhận mã OTP',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFormCard(ForgotPasswordState state) {
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
          // Step indicator
          _buildStepIndicator(state.isOtpSent),
          const SizedBox(height: 24),

          // Email field (read-only after OTP sent)
          _buildLabel('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: state.isOtpSent,
            decoration: InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slate400, size: 20),
              hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
              filled: state.isOtpSent,
              fillColor: state.isOtpSent ? AppColors.slate100 : null,
            ),
          ),

          // Step 2 fields: OTP + new password
          if (state.isOtpSent) ...[
            const SizedBox(height: 16),
            _buildLabel('Mã OTP (6 chữ số)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '123456',
                prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.slate400, size: 20),
                hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Mật khẩu mới'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _newPasswordController,
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
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: AppTheme.btnHeightLg,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : (state.isOtpSent ? _resetPassword : _sendOtp),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      state.isOtpSent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          if (state.isOtpSent) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(forgotPasswordProvider.notifier)
                        .sendOtp(_emailController.text.trim()),
                child: Text(
                  'Gửi lại mã OTP',
                  style: GoogleFonts.nunito(
                    color: AppColors.indigo600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isOtpSent) {
    return Row(
      children: [
        _buildStep(1, 'Email', !isOtpSent, true),
        Expanded(
          child: Container(
            height: 2,
            color: isOtpSent ? AppColors.indigo600 : AppColors.slate200,
          ),
        ),
        _buildStep(2, 'Xác nhận', isOtpSent, isOtpSent),
      ],
    );
  }

  Widget _buildStep(int number, String label, bool isActive, bool isDone) {
    final color = (isActive || isDone) ? AppColors.indigo600 : AppColors.slate300;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: (isActive || isDone) ? AppColors.indigo600 : Colors.white,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: (isActive || isDone) ? Colors.white : AppColors.slate400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(ForgotPasswordState state) {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            ref.read(forgotPasswordProvider.notifier).reset();
            context.pop();
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 16),
          label: Text(
            'Quay lại đăng nhập',
            style: GoogleFonts.nunito(color: AppColors.slate500, fontSize: 13),
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
}
