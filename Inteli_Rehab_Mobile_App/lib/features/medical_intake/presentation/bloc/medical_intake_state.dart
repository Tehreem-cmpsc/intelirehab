abstract class MedicalIntakeState {
  const MedicalIntakeState();
}

class MedicalIntakeInitial extends MedicalIntakeState {
  const MedicalIntakeInitial();
}

class MedicalIntakeSubmitting extends MedicalIntakeState {
  const MedicalIntakeSubmitting();
}

class MedicalIntakeSuccess extends MedicalIntakeState {
  const MedicalIntakeSuccess();
}

class MedicalIntakeError extends MedicalIntakeState {
  final String message;
  const MedicalIntakeError(this.message);
}
