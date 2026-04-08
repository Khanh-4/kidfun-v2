import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/profile_provider.dart';
import '../../../shared/models/profile_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.profile.profileName);
    _selectedDate = widget.profile.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.indigo600,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref.read(profileProvider.notifier).updateProfile(
              widget.profile.id,
              _nameController.text.trim(),
              _selectedDate,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lưu thay đổi thành công!',
                  style: GoogleFonts.nunito()),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(e.toString(), style: GoogleFonts.nunito()),
                backgroundColor: AppColors.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: Text('Xác nhận xóa',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700, color: AppColors.slate800)),
        content: Text(
          'Bạn có chắc muốn xóa hồ sơ của ${widget.profile.profileName}? Hành động này không thể hoàn tác.',
          style: GoogleFonts.nunito(
              color: AppColors.slate600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy',
                style: GoogleFonts.nunito(color: AppColors.slate500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10)),
            child: Text('Xóa',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await ref
            .read(profileProvider.notifier)
            .deleteProfile(widget.profile.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa hồ sơ thành công!',
                  style: GoogleFonts.nunito()),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(e.toString(), style: GoogleFonts.nunito()),
                backgroundColor: AppColors.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(title: const Text('Sửa hồ sơ con')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                _buildAvatarPreview(initials),
                const SizedBox(height: 28),
                _buildFormCard(),
                const SizedBox(height: 20),
                _buildManagementSection(),
                const SizedBox(height: 24),
                SizedBox(
                  height: AppTheme.btnHeightLg,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || _isDeleting ? null : _saveChanges,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Lưu thay đổi',
                            style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: AppTheme.btnHeightSm,
                  child: TextButton(
                    onPressed:
                        _isLoading || _isDeleting ? null : _deleteProfile,
                    child: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: AppColors.danger, strokeWidth: 2),
                          )
                        : Text('Xóa hồ sơ',
                            style: GoogleFonts.nunito(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview(String initials) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.linkDeviceGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.profile.profileName,
              style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate700)),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel('Tên của bé'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ví dụ: Minh Anh',
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.slate400, size: 20),
              hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Vui lòng nhập tên';
              if (value.trim().length > 50)
                return 'Tên không được quá 50 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildLabel('Ngày sinh (Không bắt buộc)'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.slate200),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusInput),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.slate400, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'Chọn ngày sinh'
                          : DateFormat('dd/MM/yyyy')
                              .format(_selectedDate!),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: _selectedDate == null
                            ? AppColors.slate400
                            : AppColors.slate800,
                      ),
                    ),
                  ),
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: const Icon(Icons.close,
                          color: AppColors.slate400, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection() {
    final pid = widget.profile.id;
    final name = Uri.encodeComponent(widget.profile.profileName);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Quản lý',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500)),
          ),
          Divider(height: 1, color: AppColors.slate100),
          _buildManagementTile(
            icon: Icons.timer_outlined,
            iconBg: AppColors.requestBg,
            iconColor: AppColors.indigo600,
            label: 'Giới hạn thời gian',
            onTap: () => context.push(
                '/profiles/$pid/time-limit?name=$name'),
          ),
          Divider(height: 1, color: AppColors.slate100),
          _buildManagementTile(
            icon: Icons.block_rounded,
            iconBg: AppColors.dangerBg,
            iconColor: AppColors.danger,
            label: 'Chặn ứng dụng',
            onTap: () => context.push(
                '/profiles/$pid/app-blocking?name=$name'),
          ),
          Divider(height: 1, color: AppColors.slate100),
          _buildManagementTile(
            icon: Icons.bar_chart_rounded,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: AppColors.purple600,
            label: 'Báo cáo sử dụng',
            onTap: () => context.push(
                '/profiles/$pid/app-usage?name=$name'),
          ),
          Divider(height: 1, color: AppColors.slate100),
          _buildManagementTile(
            icon: Icons.map_outlined,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0EA5E9),
            label: 'Vị trí & Vùng an toàn',
            onTap: () => context.push(
                '/profiles/$pid/location?name=$name'),
          ),
          Divider(height: 1, color: AppColors.slate100),
          _buildManagementTile(
            icon: Icons.history_rounded,
            iconBg: const Color(0xFFF1F5F9), // slate 100
            iconColor: const Color(0xFF64748B), // slate 500
            label: 'Lịch sử di chuyển',
            onTap: () => context.push(
                '/profiles/$pid/location-history?name=$name'),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.slate700),
    );
  }
}
