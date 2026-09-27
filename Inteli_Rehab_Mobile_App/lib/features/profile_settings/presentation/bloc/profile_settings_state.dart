abstract class ProfileSettingsState {
  const ProfileSettingsState();
}

class ProfileSettingsInitial extends ProfileSettingsState {
  const ProfileSettingsInitial();
}

class ProfileSettingsLoading extends ProfileSettingsState {
  const ProfileSettingsLoading();
}

class ProfileSettingsLoaded extends ProfileSettingsState {
  final dynamic profile;
  const ProfileSettingsLoaded(this.profile);
}

class ProfileSettingsError extends ProfileSettingsState {
  final String message;
  const ProfileSettingsError(this.message);
}
