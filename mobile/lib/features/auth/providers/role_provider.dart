import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleStateData {
  final String? role;
  final bool isLinked;
  const RoleStateData({this.role, this.isLinked = false});
}

final roleProvider = StateNotifierProvider<RoleNotifier, AsyncValue<RoleStateData>>((ref) {
  return RoleNotifier();
});

class RoleNotifier extends StateNotifier<AsyncValue<RoleStateData>> {
  RoleNotifier() : super(const AsyncValue.loading()) {
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      final isLinked = prefs.getBool('is_linked') ?? false;
      state = AsyncValue.data(RoleStateData(role: role, isLinked: isLinked));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setRole(String role) async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      final isLinked = prefs.getBool('is_linked') ?? false;
      state = AsyncValue.data(RoleStateData(role: role, isLinked: isLinked));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setLinked(bool isLinked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_linked', isLinked);
      if (state is AsyncData<RoleStateData>) {
        state = AsyncValue.data(RoleStateData(role: state.value!.role, isLinked: isLinked));
      } else {
        await _loadRole();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearRole() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('is_linked');
      state = const AsyncValue.data(RoleStateData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
