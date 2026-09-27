import '../entities/user_profile_entity.dart';
import '../repositories/profile_settings_repository.dart';

class GetUserProfileUsecase {
  final ProfileSettingsRepository repository;
  const GetUserProfileUsecase(this.repository);

  Future<UserProfileEntity> call() {
    return repository.getProfile();
  }
}
