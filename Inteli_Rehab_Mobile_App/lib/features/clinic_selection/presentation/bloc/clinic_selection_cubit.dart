import 'clinic_selection_state.dart';

class ClinicSelectionCubit {
  ClinicSelectionState _state = const ClinicSelectionInitial();
  ClinicSelectionState get state => _state;

  void emit(ClinicSelectionState newState) {
    _state = newState;
  }

  void fetchClinics() {}
}
