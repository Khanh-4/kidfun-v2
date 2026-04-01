# Bước 2 — Auth Screens (Login / Register / Forgot Password)

> **Branch:** `feat/ui/parent/auth-screens`  
> **Trạng thái:** ⬜ Chưa làm  
> **Files:**
> - `mobile/lib/features/auth/screens/login_screen.dart`
> - `mobile/lib/features/auth/screens/register_screen.dart`
> - `mobile/lib/features/auth/screens/forgot_password_screen.dart`

---

## Mục tiêu

3 màn hình auth dùng chung layout: nền `slate50`, logo + form card trắng, nút indigo.  
Giữ nguyên toàn bộ logic (authProvider, validation, navigation).

---

## Layout chung cho cả 3 màn hình

```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  body: SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Column(children: [
        _buildLogo(),        // Logo + tên app
        _buildFormCard(),    // Form fields trong card trắng
        _buildFooterLinks(), // Link chuyển trang
      ]),
    ),
  ),
)
```

---

## Logo section (dùng chung)

```dart
Widget _buildLogo() {
  return Column(children: [
    SizedBox(height: 48),
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.linkDeviceGradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.indigo600.withOpacity(0.30), blurRadius: 16, offset: Offset(0,6))],
      ),
      child: Icon(Icons.shield_outlined, size: 40, color: Colors.white),
    ),
    SizedBox(height: 12),
    Text('KidShield',
        style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.slate800)),
    Text('Bảo vệ con yêu của bạn',
        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
    SizedBox(height: 32),
  ]);
}
```

---

## Form Card (card trắng bao bọc input)

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    border: Border.all(color: AppColors.slate200),
    boxShadow: [BoxShadow(color: AppColors.slate900.withOpacity(0.06), blurRadius: 16, offset: Offset(0,4))],
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    // Title
    Text('Đăng nhập', // hoặc "Tạo tài khoản", "Lấy lại mật khẩu"
        style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.slate800)),
    SizedBox(height: 4),
    Text('Chào mừng trở lại!',
        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
    SizedBox(height: 24),

    // Error banner (nếu có)
    if (_errorMessage != null) _buildErrorBanner(_errorMessage!),

    // Fields
    _buildField(label: 'Email', controller: _emailController, icon: Icons.email_outlined),
    SizedBox(height: 12),
    _buildField(label: 'Mật khẩu', controller: _passwordController, icon: Icons.lock_outline, isPassword: true),
    SizedBox(height: 24),

    // Submit button
    SizedBox(
      width: double.infinity, height: AppTheme.btnHeightLg,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Đăng nhập', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
  ]),
)
```

### Field helper (dùng chung)
```dart
Widget _buildField({required String label, required TextEditingController controller,
    required IconData icon, bool isPassword = false}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
    SizedBox(height: 6),
    TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 20),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.slate400, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ) : null,
      ),
    ),
  ]);
}
```

### Error banner
```dart
Widget _buildErrorBanner(String message) {
  return Container(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.dangerBg,
      border: Border.all(color: AppColors.dangerBorder),
      borderRadius: BorderRadius.circular(AppTheme.radiusBtnSm),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: AppColors.danger, size: 18),
      SizedBox(width: 8),
      Expanded(child: Text(message,
          style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13))),
    ]),
  );
}
```

---

## Footer links

```dart
// Login screen footer:
Column(children: [
  SizedBox(height: 16),
  TextButton(
    onPressed: () => context.push('/forgot-password'),
    child: Text('Quên mật khẩu?',
        style: GoogleFonts.nunito(color: AppColors.indigo600, fontWeight: FontWeight.w600)),
  ),
  TextButton(
    onPressed: () => context.push('/register'),
    child: Text('Chưa có tài khoản? Đăng ký ngay',
        style: GoogleFonts.nunito(color: AppColors.slate500, fontSize: 13)),
  ),
  Divider(height: 32, color: AppColors.slate200),
  TextButton.icon(
    onPressed: () => ref.read(roleProvider.notifier).clearRole(),
    icon: Icon(Icons.swap_horiz, color: AppColors.slate400, size: 18),
    label: Text('Đổi vai trò', style: GoogleFonts.nunito(color: AppColors.slate400, fontSize: 13)),
  ),
])
```

---

## Register screen — thêm fields

```dart
_buildField(label: 'Họ và tên', controller: _nameController, icon: Icons.person_outline),
SizedBox(height: 12),
_buildField(label: 'Email', controller: _emailController, icon: Icons.email_outlined),
SizedBox(height: 12),
_buildField(label: 'Mật khẩu', controller: _passwordController, icon: Icons.lock_outline, isPassword: true),
SizedBox(height: 12),
_buildField(label: 'Xác nhận mật khẩu', controller: _confirmController, icon: Icons.lock_outline, isPassword: true),
```

---

## Forgot Password screen — đơn giản

```dart
// Chỉ 1 field email + nút "Gửi link đặt lại"
// Thêm success state: icon checkmark + hướng dẫn check email
```

---

## Commit message

```
feat(mobile/ui): redesign Auth screens — login, register, forgot password
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step2-AuthScreens.md`.
Tạo branch `feat/ui/parent/auth-screens` từ develop.
Redesign 3 file:
- mobile/lib/features/auth/screens/login_screen.dart
- mobile/lib/features/auth/screens/register_screen.dart
- mobile/lib/features/auth/screens/forgot_password_screen.dart
Giữ nguyên toàn bộ logic auth (authProvider, navigation).
Chỉ thay đổi UI theo plan.
Commit + push + PR về develop.
```
