import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final roleProvider = StateNotifierProvider<RoleNotifier, AsyncValue<String?>>((ref) {
  return RoleNotifier();
});

class RoleNotifier extends StateNotifier<AsyncValue<String?>> {
  RoleNotifier() : super(const AsyncValue.loading()) {
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      state = AsyncValue.data(role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setRole(String role) async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      state = AsyncValue.data(role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearRole() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
