import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/profile_settings_repository.dart';
import '../datasources/profile_settings_remote_data_source.dart';
import '../models/user_profile_model.dart';

class ProfileSettingsRepositoryImpl implements ProfileSettingsRepository {
  final ProfileSettingsRemoteDataSource remoteDataSource;

  const ProfileSettingsRepositoryImpl(this.remoteDataSource);

  @override
  Future<UserProfileEntity> getProfile() {
    return remoteDataSource.getProfile();
  }

  @override
  Future<void> updateProfile(UserProfileEntity profile) {
    final model = UserProfileModel(
      id: profile.id,
      name: profile.name,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      injuredArm: profile.injuredArm,
    );
    return remoteDataSource.updateProfile(model);
  }
}
