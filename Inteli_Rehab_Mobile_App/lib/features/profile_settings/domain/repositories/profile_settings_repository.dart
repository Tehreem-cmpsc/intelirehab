import '../entities/user_profile_entity.dart';

abstract class ProfileSettingsRepository {
  Future<UserProfileEntity> getProfile();
  Future<void> updateProfile(UserProfileEntity profile);
}
