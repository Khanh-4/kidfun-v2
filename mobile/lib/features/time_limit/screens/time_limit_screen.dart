import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/time_limit_provider.dart';
import '../../../shared/models/time_limit_model.dart';

// BUG 1 FIX: Converted to ConsumerStatefulWidget so TextEditingControllers
// persist across rebuilds. Previously, controllers were created inline in
// build() — every Slider move triggered a rebuild + controller reset, which
// discarded in-progress typing and caused the UI to appear glitchy.
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
  /// but only update the text if the field doesn't currently have focus —
  /// this preserves in-progress typing.
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
    final notifier = ref.read(timeLimitProvider(widget.profileId).notifier);

    // Sync text controllers whenever state changes
    if (state is TimeLimitLoaded) {
      _syncControllers(state.limits);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Giới hạn thời gian — ${widget.profileName}'),
      ),
      body: state is TimeLimitLoading || state is TimeLimitInitial
          ? const Center(child: CircularProgressIndicator())
          : state is TimeLimitError
              ? _buildErrorPlaceholder(state.message, notifier)
              : state is TimeLimitLoaded
                  ? _buildLimitList(context, state, notifier)
                  : const SizedBox.shrink(),
      bottomNavigationBar: state is TimeLimitLoaded
          ? _buildBottomButton(context, state, notifier)
          : null,
    );
  }

  Widget _buildErrorPlaceholder(String message, TimeLimitNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Lỗi: $message', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => notifier.fetchTimeLimits(),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitList(BuildContext context, TimeLimitLoaded state, TimeLimitNotifier notifier) {
    return Column(
      children: [
        if (state.limits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  final value = state.limits[0].limitMinutes;
                  for (int i = 0; i < 7; i++) {
                    notifier.updateDayLimit(state.limits[i].dayOfWeek, value, state.limits[i].isActive);
                  }
                },
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Áp dụng cho tất cả'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: state.limits.length,
            separatorBuilder: (_, __) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final limit = state.limits[index];
              return _buildDayRow(limit, notifier);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayRow(TimeLimitModel limit, TimeLimitNotifier notifier) {
    // Retrieve the persistent controller for this day
    final controller = _controllers[limit.dayOfWeek]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              limit.dayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  limit.isActive ? limit.formattedTime : 'Tắt',
                  style: TextStyle(
                    fontSize: 16,
                    color: limit.isActive ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: limit.isActive,
                  onChanged: (val) {
                    notifier.updateDayLimit(limit.dayOfWeek, limit.limitMinutes, val);
                  },
                ),
              ],
            ),
          ],
        ),
        if (limit.isActive)
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: limit.limitMinutes.toDouble(),
                  min: 0,
                  max: 720,
                  divisions: 720 ~/ 5, // Step 5 minutes
                  onChanged: (val) {
                    // BUG 1 FIX: calls notifier.updateDayLimit (in-memory only).
                    // Server save only happens when the "Lưu thay đổi" button is tapped.
                    notifier.updateDayLimit(limit.dayOfWeek, val.toInt(), true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // BUG 1 FIX: widened from 70 → 90 so "720 ph" fits without clipping.
              // Also uses the persistent controller (not an inline-created one).
              SizedBox(
                width: 100, // Widened to 100 to ensure 3-digit numbers + ' ph' fit comfortably
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: controller,
                  onSubmitted: (v) {
                    final mins = int.tryParse(v) ?? 0;
                    notifier.updateDayLimit(limit.dayOfWeek, mins.clamp(0, 720), true);
                  },
                  decoration: const InputDecoration(
                    suffixText: 'ph',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context, TimeLimitLoaded state, TimeLimitNotifier notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: state.isSaving
              ? null
              : () async {
                  final success = await notifier.saveChanges();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ Đã lưu thay đổi thành công' : '❌ Lỗi khi lưu thay đổi'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: state.isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  '💾 LƯU THAY ĐỔI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
