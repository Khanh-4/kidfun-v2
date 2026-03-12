import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

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

    // Lắng nghe error message và isSuccess
    ref.listen<ForgotPasswordState>(forgotPasswordProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        leading: BackButton(
          onPressed: () {
            ref.read(forgotPasswordProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                state.isOtpSent
                    ? 'Nhập mã OTP đã gửi đến\n${_emailController.text}'
                    : 'Nhập email để nhận mã OTP 6 số',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Email field (read-only sau khi OTP đã gửi)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: state.isOtpSent,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: state.isOtpSent ? Colors.grey.shade100 : Colors.white,
                ),
              ),

              // ── Bước 2: Hiện sau khi OTP đã gửi ──
              if (state.isOtpSent) ...[
                const SizedBox(height: 16),

                // OTP field
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: 'Mã OTP 6 số',
                    prefixIcon: Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                // New password field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action button
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : (state.isOtpSent ? _resetPassword : _sendOtp),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(state.isOtpSent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP'),
              ),

              // Gửi lại OTP
              if (state.isOtpSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                          .read(forgotPasswordProvider.notifier)
                          .sendOtp(_emailController.text.trim()),
                  child: const Text('Gửi lại mã OTP'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
