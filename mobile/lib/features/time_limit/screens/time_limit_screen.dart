import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/time_limit_provider.dart';
import '../../../shared/models/time_limit_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

// BUG 1 FIX: ConsumerStatefulWidget so TextEditingControllers persist
// across rebuilds. Inline-created controllers got reset on every Slider move.
class TimeLimitScreen extends ConsumerStatefulWidget {
  final int profileId;
  final String profileName;

  const TimeLimitScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  ConsumerState<TimeLimitScreen> createState() => _TimeLimitScreenState();
}

class _TimeLimitScreenState extends ConsumerState<TimeLimitScreen> {
  // One persistent controller per day-of-week (0–6)
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 7; i++) {
      _controllers[i] = TextEditingController();
    }
  }

  /// Keep controllers in sync when state changes externally (e.g. "Apply All")
  /// but only update text if the field doesn't have focus — preserves typing.
  void _syncControllers(List<TimeLimitModel> limits) {
    for (final limit in limits) {
      final ctrl = _controllers[limit.dayOfWeek];
      if (ctrl == null) continue;
      final newText = '${limit.limitMinutes}';
      if (ctrl.text != newText && !ctrl.selection.isValid) {
        ctrl.text = newText;
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timeLimitProvider(widget.profileId));
    final notifier =
        ref.read(timeLimitProvider(widget.profileId).notifier);

    if (state is TimeLimitLoaded) {
      _syncControllers(state.limits);
    }

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: Text('Giới hạn — ${widget.profileName}',
            overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(state, notifier),
      bottomNavigationBar: state is TimeLimitLoaded
          ? _buildSaveBar(context, state, notifier)
          : null,
    );
  }

  Widget _buildBody(TimeLimitState state, TimeLimitNotifier notifier) {
    if (state is TimeLimitLoading || state is TimeLimitInitial) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600));
    }
    if (state is TimeLimitError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(state.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      color: AppColors.danger, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => notifier.fetchTimeLimits(),
                child: Text('Thử lại',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    if (state is TimeLimitLoaded) {
      return _buildLimitList(state, notifier);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLimitList(
      TimeLimitLoaded state, TimeLimitNotifier notifier) {
    return Column(
      children: [
        if (state.limits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding, 12, AppTheme.screenPadding, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thiết lập từng ngày',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500)),
                TextButton.icon(
                  onPressed: () {
                    final value = state.limits[0].limitMinutes;
                    for (int i = 0; i < 7; i++) {
                      notifier.updateDayLimit(
                          state.limits[i].dayOfWeek, value, state.limits[i].isActive);
                    }
                  },
                  icon: const Icon(Icons.copy_all_rounded,
                      size: 16, color: AppColors.indigo600),
                  label: Text('Áp dụng tất cả',
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.indigo600)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding, vertical: 8),
            itemCount: state.limits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildDayCard(state.limits[index], notifier),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(TimeLimitModel limit, TimeLimitNotifier notifier) {
    final controller = _controllers[limit.dayOfWeek]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(
          color: limit.isActive ? AppColors.indigo600.withOpacity(0.3) : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                limit.dayName,
                style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800),
              ),
              Row(
                children: [
                  if (limit.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.requestBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        limit.formattedTime,
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.indigo600),
                      ),
                    )
                  else
                    Text('Tắt',
                        style: GoogleFonts.nunito(
                            fontSize: 13, color: AppColors.slate400)),
                  const SizedBox(width: 8),
                  Switch(
                    value: limit.isActive,
                    activeColor: AppColors.indigo600,
                    onChanged: (val) => notifier.updateDayLimit(
                        limit.dayOfWeek, limit.limitMinutes, val),
                  ),
                ],
              ),
            ],
          ),
          if (limit.isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.indigo600,
                      thumbColor: AppColors.indigo600,
                      inactiveTrackColor: AppColors.slate200,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: limit.limitMinutes.toDouble(),
                      min: 0,
                      max: 720,
                      divisions: 720 ~/ 5,
                      onChanged: (val) => notifier.updateDayLimit(
                          limit.dayOfWeek, val.toInt(), true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // BUG 1 FIX: widened to 90 so "720 ph" fits without clipping
                SizedBox(
                  width: 90,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: controller,
                    onSubmitted: (v) {
                      final mins = int.tryParse(v) ?? 0;
                      notifier.updateDayLimit(
                          limit.dayOfWeek, mins.clamp(0, 720), true);
                    },
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: AppColors.slate800),
                    decoration: InputDecoration(
                      suffixText: 'ph',
                      suffixStyle: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.slate400),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, TimeLimitLoaded state,
      TimeLimitNotifier notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: SizedBox(
          height: AppTheme.btnHeightLg,
          child: ElevatedButton(
            onPressed: state.isSaving
                ? null
                : () async {
                    final success = await notifier.saveChanges();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          success
                              ? 'Đã lưu thay đổi thành công'
                              : 'Lỗi khi lưu thay đổi',
                          style: GoogleFonts.nunito(),
                        ),
                        backgroundColor:
                            success ? AppColors.success : AppColors.danger,
                      ));
                    }
                  },
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('Lưu thay đổi',
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
