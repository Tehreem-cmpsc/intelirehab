abstract class ClinicSelectionState {
  const ClinicSelectionState();
}

class ClinicSelectionInitial extends ClinicSelectionState {
  const ClinicSelectionInitial();
}

class ClinicSelectionLoading extends ClinicSelectionState {
  const ClinicSelectionLoading();
}

class ClinicSelectionLoaded extends ClinicSelectionState {
  final List<dynamic> clinics;
  const ClinicSelectionLoaded(this.clinics);
}

class ClinicSelectionError extends ClinicSelectionState {
  final String message;
  const ClinicSelectionError(this.message);
}
