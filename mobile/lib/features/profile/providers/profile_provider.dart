import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../../../shared/models/profile_model.dart';

sealed class ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final List<ProfileModel> profiles;
  ProfileLoaded(this.profiles);
}
class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final _repo = ProfileRepository();

  ProfileNotifier() : super(ProfileLoading()) {
    fetchProfiles();
  }

  Future<void> fetchProfiles() async {
    state = ProfileLoading();
    try {
      final profiles = await _repo.getProfiles();
      state = ProfileLoaded(profiles);
    } catch (e) {
      state = ProfileError((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> createProfile(String name, DateTime? dob) async {
    try {
      await _repo.createProfile(name, dob);
      await fetchProfiles();
    } catch (e) {
      throw Exception((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateProfile(int id, String? name, DateTime? dob) async {
    try {
      await _repo.updateProfile(id, name, dob);
      await fetchProfiles();
    } catch (e) {
      throw Exception((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteProfile(int id) async {
    try {
      await _repo.deleteProfile(id);
      await fetchProfiles();
    } catch (e) {
      throw Exception((e as Exception).toString().replaceAll('Exception: ', ''));
    }
  }
}
