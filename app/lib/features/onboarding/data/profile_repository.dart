import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<Profile> getProfile() async => Profile.fromJson(await _api.getProfile());

  Future<Profile> saveOnboarding(OnboardingAnswers answers) async =>
      Profile.fromJson(await _api.updateProfile(answers.toJson()));

  Future<void> giveHealthConsent() => _api.giveConsent('health_data', healthConsentVersion);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
