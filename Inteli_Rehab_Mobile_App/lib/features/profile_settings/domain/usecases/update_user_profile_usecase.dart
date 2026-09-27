import '../entities/user_profile_entity.dart';
import '../repositories/profile_settings_repository.dart';

class UpdateUserProfileUsecase {
  final ProfileSettingsRepository repository;
  const UpdateUserProfileUsecase(this.repository);

  Future<void> call(UserProfileEntity profile) {
    return repository.updateProfile(profile);
  }
}
