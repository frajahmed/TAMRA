import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../domain/profile.dart';

/// Reads and saves the user's profile and the health-data consent.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// The profile with the targets calculated by the server.
  Future<Profile> getProfile() async =>
      Profile.fromJson(await _api.getProfile());

  /// Saves the onboarding answers; the server calculates the targets.
  Future<Profile> saveOnboarding(OnboardingAnswers answers) async =>
      Profile.fromJson(await _api.updateProfile(answers.toJson()));

  /// Stores the consent to process health data (current version).
  Future<void> giveHealthConsent() =>
      _api.giveConsent('health_data', healthConsentVersion);

  /// Changes settings such as `weight_unit`, `energy_unit` or `language`.
  Future<Profile> updateSettings(Map<String, dynamic> changes) async =>
      Profile.fromJson(await _api.updateProfile(changes));

  /// Withdraws the consent to process health data.
  Future<void> withdrawHealthConsent() => _api.withdrawConsent('health_data');

  /// All personal data as JSON text.
  Future<String> exportData() => _api.exportData();

  /// Deletes the account for good; throws [ApiError] with a `password` field when wrong.
  Future<void> deleteAccount(String password) => _api.deleteAccount(password);
}

/// The [ProfileRepository] used by consent and onboarding.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

/// The logged-in user's profile (units, targets); invalidate after changing it.
final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});
