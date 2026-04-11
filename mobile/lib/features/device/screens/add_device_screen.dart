import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/device_provider.dart';
import '../../../shared/models/profile_model.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  ProfileModel? _selectedProfile;
  String? _pairingCode;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSocketConnected = false;
  bool _isLinked = false;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _isSocketConnected = SocketService.instance.isConnected;
    if (!_isSocketConnected) {
      SocketService.instance.reconnect();
    }
    SocketService.instance.addDeviceLinkedListener(_handleSuccessfulLink);
  }

  void _handleSuccessfulLink(Map<String, dynamic> data) {
    if (!mounted || _isLinked) return;
    if (_pairingCode == null) return;

    setState(() => _isLinked = true);
    ref.read(deviceProvider.notifier).fetchDevices();

    final deviceName =
        data['deviceName']?.toString() ?? 'Thiết bị con';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thiết bị "$deviceName" đã kết nối thành công!',
            style: GoogleFonts.nunito()),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.pop();
    });
  }

  @override
  void dispose() {
    SocketService.instance.removeDeviceLinkedListener(_handleSuccessfulLink);
    super.dispose();
  }

  Future<void> _generateCode() async {
    if (_selectedProfile == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pairingCode = null;
    });
    try {
      final code = await ref
          .read(deviceProvider.notifier)
          .generatePairingCode(_selectedProfile!.id);
      if (mounted) setState(() => _pairingCode = code);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    _isSocketConnected = SocketService.instance.isConnected;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Thêm thiết bị con'),
        actions: [_buildSocketBadge()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding),
          child: _isLinked
              ? _buildSuccessState()
              : _buildInputState(profileState),
        ),
      ),
    );
  }

  Widget _buildSocketBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (_isSocketConnected ? AppColors.emerald400 : AppColors.danger)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSocketConnected ? AppColors.emerald400 : AppColors.danger,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _isSocketConnected
                  ? AppColors.emerald400
                  : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isSocketConnected ? 'Sẵn sàng' : 'Mất kết nối',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _isSocketConnected
                  ? AppColors.emerald400
                  : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 56),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Kết nối thành công!',
          style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.slate800),
        ),
        const SizedBox(height: 8),
        Text(
          'Đang quay lại danh sách thiết bị...',
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppColors.slate500),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildInputState(ProfileState profileState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        // Instruction card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            border: Border.all(color: AppColors.infoBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '1. Chọn hồ sơ của con\n2. Nhấn "Tạo mã kết nối"\n3. Mở app trên thiết bị con và nhập mã hoặc quét QR',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: AppColors.info, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Profile selector card
        Container(
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
              Text('Chọn hồ sơ của con',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700)),
              const SizedBox(height: 8),
              if (profileState is ProfileLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: AppColors.indigo600, strokeWidth: 2),
                ))
              else if (profileState is ProfileLoaded &&
                  profileState.profiles.isNotEmpty)
                DropdownButtonFormField<ProfileModel>(
                  decoration: InputDecoration(
                    hintText: 'Chọn hồ sơ',
                    hintStyle:
                        GoogleFonts.nunito(color: AppColors.slate400),
                    prefixIcon: const Icon(Icons.child_care_rounded,
                        color: AppColors.slate400, size: 20),
                  ),
                  initialValue: _selectedProfile,
                  items: (profileState)
                      .profiles
                      .map((p) => DropdownMenuItem<ProfileModel>(
                            value: p,
                            child: Text(p.profileName,
                                style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    color: AppColors.slate800)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedProfile = val;
                    _pairingCode = null;
                    _errorMessage = null;
                  }),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warningBorder),
                  ),
                  child: Text(
                    'Chưa có hồ sơ nào. Vui lòng tạo hồ sơ cho con trước.',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              border: Border.all(color: AppColors.dangerBorder),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusBtnSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!,
                      style: GoogleFonts.nunito(
                          color: AppColors.danger, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        if (_pairingCode == null)
          SizedBox(
            height: AppTheme.btnHeightLg,
            child: ElevatedButton(
              onPressed: (_selectedProfile == null || _isLoading)
                  ? null
                  : _generateCode,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Tạo mã kết nối',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          )
        else
          _buildQrSection(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQrSection() {
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
          // Waiting label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.indigo600,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang chờ kết nối...',
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // QR code
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusCardMd),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _pairingCode!,
                version: QrVersions.auto,
                size: 180.0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hoặc nhập mã thủ công',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 12, color: AppColors.slate400),
          ),
          const SizedBox(height: 10),
          // Pairing code display
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _pairingCode!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Đã sao chép mã!',
                    style: GoogleFonts.nunito()),
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.requestBg,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusCardMd),
                border: Border.all(color: AppColors.indigo700.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _pairingCode!,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppColors.indigo600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded,
                      color: AppColors.indigo600, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              _pairingCode = null;
              _errorMessage = null;
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate500,
              side: const BorderSide(color: AppColors.slate200),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusBtn)),
              minimumSize:
                  const Size.fromHeight(AppTheme.btnHeightSm),
            ),
            child: Text('Tạo mã mới',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
