import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/profile_provider.dart';
import '../../../shared/models/profile_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.profileName);
    _selectedDate = widget.profile.dateOfBirth;
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveChanges() async {
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
            const SnackBar(content: Text('Lưu thay đổi thành công!')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa hồ sơ này không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await ref.read(profileProvider.notifier).deleteProfile(widget.profile.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa hồ sơ thành công!')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa hồ sơ con')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.child_care, size: 50, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Tên của bé *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng nhập tên';
                    if (value.length > 50) return 'Tên không được quá 50 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(hintText: 'Ngày sinh (Không bắt buộc)'),
                    child: Text(
                      _selectedDate == null
                          ? 'Ngày sinh (Không bắt buộc)'
                          : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                      style: TextStyle(color: _selectedDate == null ? Colors.grey.shade600 : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/profiles/${widget.profile.id}/time-limit?name=${Uri.encodeComponent(widget.profile.profileName)}',
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Thiết lập giới hạn thời gian'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/profiles/${widget.profile.id}/app-blocking?name=${Uri.encodeComponent(widget.profile.profileName)}',
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Chặn ứng dụng'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/profiles/${widget.profile.id}/app-usage?name=${Uri.encodeComponent(widget.profile.profileName)}',
                  ),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Báo cáo sử dụng'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading || _isDeleting ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Lưu thay đổi'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading || _isDeleting ? null : _deleteProfile,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isDeleting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)) 
                    : const Text('Xóa hồ sơ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
