import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/web_filter_repository.dart';

class WebFilterScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const WebFilterScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<WebFilterScreen> createState() => _WebFilterScreenState();
}

class _WebFilterScreenState extends State<WebFilterScreen> with SingleTickerProviderStateMixin {
  final _repository = WebFilterRepository();
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _customDomains = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _repository.getBlockedCategories(widget.profileId);
      final customDomains = await _repository.getCustomDomains(widget.profileId);
      setState(() {
        _categories = categories;
        _customDomains = customDomains;
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

  Future<void> _toggleCategory(int categoryId, bool currentVal) async {
    final originalState = _categories;
    setState(() {
      final index = _categories.indexWhere((c) => c['id'] == categoryId);
      if (index != -1) {
        _categories[index] = {..._categories[index], 'isBlocked': !currentVal};
      }
    });

    try {
      await _repository.toggleCategory(widget.profileId, categoryId, !currentVal);
      // reload to get correct overrides just in case
      _loadData();
    } catch (e) {
      if (mounted) {
        setState(() => _categories = originalState); // rollback
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _addCustomDomain() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Thêm domain tự chọn',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'ví dụ: facebook.com',
            hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.nunito(color: AppColors.slate600)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: Text('Thêm', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await _repository.addCustomDomain(widget.profileId, result.toLowerCase());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã thêm $result vào danh sách chặn', style: GoogleFonts.nunito()),
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
    }
  }

  Future<void> _deleteCustomDomain(String domain) async {
    try {
      await _repository.deleteCustomDomain(widget.profileId, domain);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Lọc nội dung web', overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
          unselectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w500, fontSize: 15),
          tabs: const [
            Tab(text: 'Danh mục đen'),
            Tab(text: 'Miền tự chọn'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesTab(),
                _buildCustomDomainsTab(),
              ],
            ),
    );
  }

  Widget _buildCategoriesTab() {
    if (_categories.isEmpty) {
      return Center(
        child: Text('Không có danh mục nào.',
            style: GoogleFonts.nunito(color: AppColors.slate500)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.indigo600,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final bool isBlocked = cat['isBlocked'] ?? false;
          final int count = cat['domainCount'] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
              border: Border.all(color: isBlocked ? AppColors.danger.withValues(alpha: 0.3) : AppColors.slate200),
            ),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCardMd)),
              leading: Icon(
                isBlocked ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded,
                color: isBlocked ? AppColors.danger : AppColors.success,
              ),
              title: Text(cat['name'] ?? 'Không rõ',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text('$count trang web',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate400)),
              trailing: Switch(
                value: isBlocked,
                activeThumbColor: AppColors.danger,
                onChanged: (val) => _toggleCategory(cat['categoryId'] ?? cat['id'], isBlocked),
              ),
              children: [
                Container(
                  color: AppColors.slate50,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Khi bật, tất cả trang web thuộc danh mục này sẽ bị chặn truy cập trên trình duyệt của máy con.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomDomainsTab() {
    return Column(
      children: [
        Expanded(
          child: _customDomains.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.public_off_rounded, size: 50, color: AppColors.slate300),
                      const SizedBox(height: 16),
                      Text('Chưa có danh sách riêng',
                          style: GoogleFonts.nunito(fontSize: 16, color: AppColors.slate600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Thêm các trang web bạn muốn chặn riêng biệt tại đây.',
                          style: GoogleFonts.nunito(color: AppColors.slate400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.indigo600,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    itemCount: _customDomains.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (context, index) {
                      final item = _customDomains[index];
                      final domain = item['domain'] as String;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded, color: AppColors.warningDark, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(domain, style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 14))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                              onPressed: () => _deleteCustomDomain(domain),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addCustomDomain,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text('Thêm trang web',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
