import '../models/user_profile_model.dart';

abstract class ProfileSettingsRemoteDataSource {
  Future<UserProfileModel> getProfile();
  Future<void> updateProfile(UserProfileModel model);
}

class ProfileSettingsRemoteDataSourceImpl
    implements ProfileSettingsRemoteDataSource {
  @override
  Future<UserProfileModel> getProfile() async {
    return const UserProfileModel(
      id: '1',
      name: 'Patient',
      email: 'patient@example.com',
      phoneNumber: '',
      injuredArm: 'Right Arm',
    );
  }

  @override
  Future<void> updateProfile(UserProfileModel model) async {}
}
