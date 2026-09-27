import 'medical_intake_state.dart';

class MedicalIntakeCubit {
  MedicalIntakeState _state = const MedicalIntakeInitial();
  MedicalIntakeState get state => _state;

  void emit(MedicalIntakeState newState) {
    _state = newState;
  }

  void submitIntake() {}
}
