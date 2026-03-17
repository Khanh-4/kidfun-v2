import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/time_limit_provider.dart';
import '../../../shared/models/time_limit_model.dart';

class TimeLimitScreen extends ConsumerWidget {
  final int profileId;
  final String profileName;

  const TimeLimitScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timeLimitProvider(profileId));
    final notifier = ref.read(timeLimitProvider(profileId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Giới hạn thời gian — $profileName'),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: state.limits.length,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (context, index) {
        final limit = state.limits[index];
        return _buildDayRow(limit, notifier);
      },
    );
  }

  Widget _buildDayRow(TimeLimitModel limit, TimeLimitNotifier notifier) {
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
                  max: 300,
                  divisions: 300 ~/ 15, // Step 15 minutes
                  onChanged: (val) {
                    notifier.updateDayLimit(limit.dayOfWeek, val.toInt(), true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Text(
                  '${limit.limitMinutes}m',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.end,
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
