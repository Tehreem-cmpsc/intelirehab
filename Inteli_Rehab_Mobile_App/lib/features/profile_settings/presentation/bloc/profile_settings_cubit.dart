import 'profile_settings_state.dart';

class ProfileSettingsCubit {
  ProfileSettingsState _state = const ProfileSettingsInitial();
  ProfileSettingsState get state => _state;

  void emit(ProfileSettingsState newState) {
    _state = newState;
  }

  void loadProfile() {}
  void updateProfile() {}
}
