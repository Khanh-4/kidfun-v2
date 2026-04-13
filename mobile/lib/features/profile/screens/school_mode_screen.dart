import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/school_mode_repository.dart';

class SchoolModeScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const SchoolModeScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<SchoolModeScreen> createState() => _SchoolModeScreenState();
}

class _SchoolModeScreenState extends State<SchoolModeScreen> {
  final _repository = SchoolModeRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isEnabled = false;
  String _startTime = "07:00";
  String _endTime = "11:30";
  List<Map<String, dynamic>> _allowedApps = [];
  Map<String, dynamic> _dayOverrides = {};



  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getSchedule(widget.profileId);
      setState(() {
        _isEnabled = data['isEnabled'] ?? false;
        _startTime = data['template']?['startTime'] ?? "07:00";
        _endTime = data['template']?['endTime'] ?? "11:30";
        _dayOverrides = Map<String, dynamic>.from(data['dayOverrides'] ?? {});
        _allowedApps = List<Map<String, dynamic>>.from(data['allowedApps'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await _repository.upsertSchedule(widget.profileId, {
        'isEnabled': _isEnabled,
        'template': {
          'startTime': _startTime,
          'endTime': _endTime,
        },
        'dayOverrides': _dayOverrides,
        'allowedApps': _allowedApps,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã lưu cấu hình chế độ học tập', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _setManualOverride(String type) async {
    try {
      await _repository.manualOverride(widget.profileId, type, type == 'CLEAR' ? null : 60);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã thay đổi bộ đè: $type (1 giờ)', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.success,
        ));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<TimeOfDay?> _pickTime(String initialTime) async {
    final parts = initialTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    return showTimePicker(context: context, initialTime: initial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Chế độ học tập', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            onPressed: _isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                _buildToggleSection(),
                const SizedBox(height: 16),
                if (_isEnabled) ...[
                  _buildTemplateSection(),
                  const SizedBox(height: 16),
                  _buildAllowedAppsSection(),
                  const SizedBox(height: 16),
                  _buildManualOverrideSection(),
                ] else
                   Container(
                     padding: const EdgeInsets.all(16),
                     child: Text(
                       'Bật Chế độ học tập để thiết lập lịch chặn các thiết bị con trong giờ học.',
                       textAlign: TextAlign.center,
                       style: GoogleFonts.nunito(color: AppColors.slate500)
                     )
                   ),
              ],
            ),
    );
  }

  Widget _buildToggleSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: _isEnabled ? AppColors.indigo600.withValues(alpha: 0.5) : AppColors.slate200),
      ),
      child: SwitchListTile(
        title: Text('Bật chế độ học tập',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.slate800)),
        value: _isEnabled,
        activeThumbColor: AppColors.indigo600,
        onChanged: (val) {
          setState(() => _isEnabled = val);
        },
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: AppColors.slate200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.indigo600, size: 20),
              const SizedBox(width: 8),
              Text('Lịch học mẫu',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Khoảng thời gian này sẽ tự động chặn các ứng dụng không nằm trong danh sách cho phép (Từ Thứ 2 - Thứ 6).',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimePicker('Từ', _startTime, (val) => setState(() => _startTime = val)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker('Đến', _endTime, (val) => setState(() => _endTime = val)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, String timeStr, Function(String) onChanged) {
    return InkWell(
      onTap: () async {
        final time = await _pickTime(timeStr);
        if (time != null) {
          final hr = time.hour.toString().padLeft(2, '0');
          final min = time.minute.toString().padLeft(2, '0');
          onChanged('$hr:$min');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(height: 4),
            Text(timeStr, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.indigo600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowedAppsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: AppColors.slate200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ứng dụng được phép',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.success),
                onPressed: () {
                  _showAddAppDialog();
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          if (_allowedApps.isEmpty)
            Text('Chưa có ứng dụng nào được phép mở trong giờ học.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate400))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allowedApps.length,
              itemBuilder: (ctx, i) {
                final app = _allowedApps[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apps_rounded, color: AppColors.indigo400),
                  title: Text(app['packageName'], style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                    onPressed: () {
                      setState(() {
                         _allowedApps.removeAt(i);
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildManualOverrideSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tác động tức thì',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.danger)),
          const SizedBox(height: 8),
          Text('Trực tiếp bật/tắt thiết bị của con ngay bây giờ. Có hiệu lực 1 giờ.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setManualOverride('FORCE_ON'),
                  icon: const Icon(Icons.school, color: AppColors.warningDark),
                  label: const Text('Bắt học', style: TextStyle(color: AppColors.warningDark)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.warningDark)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setManualOverride('FORCE_OFF'),
                  icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.success),
                  label: const Text('Cho nghỉ', style: TextStyle(color: AppColors.success)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.success)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _setManualOverride('CLEAR'),
              child: const Text('Khôi phục lịch bình thường', style: TextStyle(color: AppColors.slate500)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showAddAppDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm ứng dụng', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'com.example.app (package name)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _allowedApps.add({'packageName': result});
      });
    }
  }
}
