import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class AIAlertDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const AIAlertDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final dangerLevel = (data['dangerLevel'] as int?) ?? 4;
    final category = data['category'] as String? ?? 'UNKNOWN';
    final videoTitle = data['videoTitle'] as String? ?? 'Không xác định';
    final channelName = data['channelName'] as String? ?? '';
    final summary = data['summary'] as String? ?? '';
    final profileName = data['profileName'] as String? ?? 'Con';

    final isExtreme = dangerLevel >= 5;
    final primaryColor = isExtreme ? Colors.red.shade900 : Colors.red;
    final bgColor = isExtreme ? Colors.red.shade50 : Colors.orange.shade50;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alert icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: primaryColor, size: 48),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                '⚠️ NỘI DUNG NGUY HIỂM',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // Danger level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Mức độ $dangerLevel/5 · $category',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              // Profile watched
              Text('$profileName đã xem:', style: GoogleFonts.nunito(fontSize: 14, color: AppColors.slate600, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // Video card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC0000).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_circle_filled, color: Color(0xFFCC0000), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(videoTitle, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (channelName.isNotEmpty)
                            Text(channelName, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // AI Summary
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(179),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('🤖 $summary', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate700)),
                ),
              ],
              const SizedBox(height: 12),
              // Auto-blocked notice
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('Video đã được tự động chặn', style: GoogleFonts.nunito(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),
              // Actions
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Đã hiểu', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'view_details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Xem chi tiết', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
