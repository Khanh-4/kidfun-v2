# Bước 1 — Design Tokens

> **Branch:** `feat/ui/design-tokens`  
> **Trạng thái:** ✅ Xong

---

## Mục tiêu

Cập nhật `AppColors` và `AppTheme` để phản ánh đúng design system của KidShield spec.  
Tất cả màu sắc, border radius, text styles sẽ dùng từ đây — các bước sau không hardcode giá trị.

---

## Files cần sửa

| File | Action |
|------|--------|
| `mobile/lib/core/constants/app_colors.dart` | Rewrite toàn bộ |
| `mobile/lib/core/theme/app_theme.dart` | Rewrite toàn bộ |

---

## Nội dung mới cho `app_colors.dart`

```dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Gradients Child ─────────────────────────────────────────────────
  // 4.1 LinkDevice:      #6366F1 → #9333EA → #EC4899
  static const linkDeviceGradient = [Color(0xFF6366F1), Color(0xFF9333EA), Color(0xFFEC4899)];

  // 4.2 TimeRemaining:   #7C3AED → #4F46E5 → #1D4ED8
  static const timeRemainingGradient = [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF1D4ED8)];

  // 4.3 LockedPage:      #0F172A → #1E293B → #1E1B4B
  static const lockedGradient = [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E1B4B)];

  // 4.4 RequestTime:     #FB923C → #EC4899 → #F43F5E
  static const requestTimeGradient = [Color(0xFFFB923C), Color(0xFFEC4899), Color(0xFFF43F5E)];

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF059669); // emerald-600
  static const Color successBg    = Color(0xFFECFDF5); // emerald-50
  static const Color successBorder = Color(0xFFA7F3D0); // emerald-100

  static const Color warning      = Color(0xFFD97706); // amber-600
  static const Color warningBg    = Color(0xFFFFFBEB); // amber-50
  static const Color warningBorder = Color(0xFFFDE68A); // amber-100

  static const Color danger       = Color(0xFFE11D48); // rose-600
  static const Color dangerBg     = Color(0xFFFFF1F2); // rose-50
  static const Color dangerBorder = Color(0xFFFFE4E6); // rose-100

  static const Color info         = Color(0xFF2563EB); // blue-600
  static const Color infoBg       = Color(0xFFEFF6FF); // blue-50
  static const Color infoBorder   = Color(0xFFDBEAFE); // blue-100

  static const Color request      = Color(0xFF4F46E5); // indigo-600
  static const Color requestBg    = Color(0xFFEEF2FF); // indigo-50
  static const Color requestBorder = Color(0xFFC7D2FE); // indigo-100

  // ── Slate palette ────────────────────────────────────────────────────
  static const Color slate50  = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // ── Brand ────────────────────────────────────────────────────────────
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color purple500 = Color(0xFFA855F7);
  static const Color purple600 = Color(0xFF9333EA);
  static const Color rose500   = Color(0xFFF43F5E);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color amber400  = Color(0xFFFBBF24);
  static const Color orange400 = Color(0xFFFB923C);

  // ── Glass / Overlay ──────────────────────────────────────────────────
  // Dùng: Colors.white.withOpacity(0.15) cho glass card
  // Dùng: Colors.white.withOpacity(0.20) cho ghost button
  // Dùng: Colors.white.withOpacity(0.10) cho subtle bg

  // ── Legacy (giữ lại để không break parent screens) ───────────────────
  static const Color primary      = indigo600;
  static const Color primaryDark  = indigo700;
  static const Color primaryLight = Color(0xFFBBDEFB);
  static const Color accent       = orange400;
  static const Color background   = slate50;
  static const Color surface      = Colors.white;
  static const Color error        = danger;
  static const Color textPrimary  = slate800;
  static const Color textSecondary = slate500;
}
```

---

## Nội dung mới cho `app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // ── Border Radius constants ───────────────────────────────────────────
  static const double radiusCard    = 24.0; // rounded-3xl
  static const double radiusCardMd  = 16.0; // rounded-2xl
  static const double radiusBtn     = 16.0; // rounded-2xl
  static const double radiusBtnSm   = 12.0; // rounded-xl
  static const double radiusInput   = 12.0; // rounded-xl
  static const double radiusIconSm  = 12.0; // rounded-xl
  static const double radiusPill    = 9999.0; // rounded-full

  // ── Spacing constants ─────────────────────────────────────────────────
  static const double screenPadding = 20.0;  // p-5
  static const double cardPadding   = 20.0;  // card padding
  static const double gap           = 12.0;  // gap-3
  static const double btnHeightLg   = 54.0;  // py-3.5 ~ 56px
  static const double btnHeightSm   = 38.0;  // py-2 ~ 40px

  // ── Text Styles ──────────────────────────────────────────────────────
  static TextStyle pageTitle(Color color) =>
      GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: color);

  static TextStyle sectionHeading(Color color) =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: color);

  static TextStyle cardTitle(Color color) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: color);

  static TextStyle body(Color color) =>
      GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: color);

  static TextStyle caption(Color color) =>
      GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400, color: color);

  static TextStyle heroNumber(Color color) =>
      GoogleFonts.nunito(fontSize: 56, fontWeight: FontWeight.w800, color: color);

  static TextStyle clockText(Color color) =>
      GoogleFonts.nunito(fontSize: 64, fontWeight: FontWeight.w800, color: color);

  // ── Decoration helpers ────────────────────────────────────────────────

  /// Glass card dùng trên nền gradient
  static BoxDecoration glassCard({double radius = radiusCard}) => BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withOpacity(0.20)),
  );

  /// Glass card mờ hơn (bg-white/10)
  static BoxDecoration glassCardSubtle({double radius = radiusCard}) => BoxDecoration(
    color: Colors.white.withOpacity(0.10),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withOpacity(0.10)),
  );

  /// Gradient background helper
  static BoxDecoration gradientBg(List<Color> colors) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ),
  );

  // ── MaterialApp ThemeData ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.indigo600,
        secondary: AppColors.orange400,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.indigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigo600,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(btnHeightLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
          ),
          elevation: 4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.indigo500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
    );
  }
}
```

---

## Lưu ý khi implement

- `Colors.white` trong Dart = `const Color(0xFFFFFFFF)`, dùng `.withOpacity(x)` cho các giá trị glass
- `googleFonts` package đã có trong `pubspec.yaml` (đang dùng ở dashboard screen)
- Kiểm tra build sau khi sửa: `flutter build apk --debug` hoặc hot reload

---

## Commit message

```
feat(mobile/ui): update design tokens — AppColors + AppTheme theo KidShield spec
```

---

## Prompt để tiếp tục (copy vào session mới)

```
Đọc file `UI/Plan Upgrade UI/Step1-Design-Tokens.md` trong project kidfun-v2.
Tạo branch `feat/ui/design-tokens` từ develop, sau đó implement toàn bộ nội dung
trong file đó: rewrite `mobile/lib/core/constants/app_colors.dart` và
`mobile/lib/core/theme/app_theme.dart` theo code mẫu trong file plan.
Sau khi xong commit và push, tạo PR về develop.
```
