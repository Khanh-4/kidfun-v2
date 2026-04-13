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
  static const Color success       = Color(0xFF059669); // emerald-600
  static const Color successBg     = Color(0xFFECFDF5); // emerald-50
  static const Color successBorder = Color(0xFFA7F3D0); // emerald-100

  static const Color warning       = Color(0xFFD97706); // amber-600
  static const Color warningDark   = Color(0xFFB45309); // amber-700
  static const Color warningBg     = Color(0xFFFFFBEB); // amber-50
  static const Color warningBorder = Color(0xFFFDE68A); // amber-100

  static const Color danger        = Color(0xFFE11D48); // rose-600
  static const Color dangerBg      = Color(0xFFFFF1F2); // rose-50
  static const Color dangerBorder  = Color(0xFFFFE4E6); // rose-100

  static const Color info          = Color(0xFF2563EB); // blue-600
  static const Color infoBg        = Color(0xFFEFF6FF); // blue-50
  static const Color infoBorder    = Color(0xFFDBEAFE); // blue-100

  static const Color request       = Color(0xFF4F46E5); // indigo-600
  static const Color requestBg     = Color(0xFFEEF2FF); // indigo-50
  static const Color requestBorder = Color(0xFFC7D2FE); // indigo-100

  // ── Slate palette ────────────────────────────────────────────────────
  static const Color slate50  = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
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

  // ── Legacy (giữ lại để không break parent screens) ───────────────────
  static const Color primary       = indigo600;
  static const Color primaryDark   = indigo700;
  static const Color primaryLight  = Color(0xFFBBDEFB);
  static const Color accent        = orange400;
  static const Color background    = slate50;
  static const Color surface       = Colors.white;
  static const Color error         = danger;
  static const Color textPrimary   = slate800;
  static const Color textSecondary = slate500;
}
