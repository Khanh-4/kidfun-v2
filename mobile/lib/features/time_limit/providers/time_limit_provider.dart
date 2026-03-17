import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/time_limit_repository.dart';
import '../../../shared/models/time_limit_model.dart';

final timeLimitProvider = StateNotifierProvider.family<TimeLimitNotifier, TimeLimitState, int>((ref, profileId) {
  return TimeLimitNotifier(profileId);
});

sealed class TimeLimitState {}

class TimeLimitInitial extends TimeLimitState {}

class TimeLimitLoading extends TimeLimitState {}

class TimeLimitLoaded extends TimeLimitState {
  final List<TimeLimitModel> limits;
  final bool isSaving;
  TimeLimitLoaded({required this.limits, this.isSaving = false});

  TimeLimitLoaded copyWith({List<TimeLimitModel>? limits, bool? isSaving}) {
    return TimeLimitLoaded(
      limits: limits ?? this.limits,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class TimeLimitError extends TimeLimitState {
  final String message;
  TimeLimitError(this.message);
}

class TimeLimitNotifier extends StateNotifier<TimeLimitState> {
  final int profileId;
  final _repo = TimeLimitRepository();

  TimeLimitNotifier(this.profileId) : super(TimeLimitInitial()) {
    fetchTimeLimits();
  }

  Future<void> fetchTimeLimits() async {
    state = TimeLimitLoading();
    try {
      final limits = await _repo.getTimeLimits(profileId);
      
      // Đảm bảo có đủ 7 ngày, nếu thiếu ngày nào thì bù ngày đó với limit=0
      final List<TimeLimitModel> fullLimits = List.generate(7, (index) {
        final existing = limits.where((l) => l.dayOfWeek == index).toList();
        return existing.isNotEmpty 
          ? existing.first 
          : TimeLimitModel(dayOfWeek: index, limitMinutes: 0, isActive: false);
      });

      state = TimeLimitLoaded(limits: fullLimits);
    } catch (e) {
      state = TimeLimitError(e.toString());
    }
  }

  void updateDayLimit(int dayOfWeek, int minutes, bool isActive) {
    if (state is TimeLimitLoaded) {
      final currentState = state as TimeLimitLoaded;
      final newLimits = currentState.limits.map((l) {
        if (l.dayOfWeek == dayOfWeek) {
          return l.copyWith(limitMinutes: minutes, isActive: isActive);
        }
        return l;
      }).toList();
      state = currentState.copyWith(limits: newLimits);
    }
  }

  Future<bool> saveChanges() async {
    if (state is! TimeLimitLoaded) return false;
    
    final currentState = state as TimeLimitLoaded;
    state = currentState.copyWith(isSaving: true);
    
    try {
      await _repo.updateTimeLimits(profileId, currentState.limits);
      state = currentState.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = currentState.copyWith(isSaving: false);
      return false;
    }
  }
}
