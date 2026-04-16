import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/daily_report_tab.dart';
import '../widgets/weekly_report_tab.dart';

class ReportsScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const ReportsScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.indigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Báo cáo sử dụng', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.profileName, style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.today, size: 18), text: 'Hôm nay'),
            Tab(icon: Icon(Icons.calendar_view_week, size: 18), text: 'Tuần này'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DailyReportTab(profileId: widget.profileId),
          WeeklyReportTab(profileId: widget.profileId),
        ],
      ),
    );
  }
}
