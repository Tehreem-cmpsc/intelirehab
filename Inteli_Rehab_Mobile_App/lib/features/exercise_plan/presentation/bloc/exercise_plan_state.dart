abstract class ExercisePlanState {
  const ExercisePlanState();
}

class ExercisePlanInitial extends ExercisePlanState {
  const ExercisePlanInitial();
}

class ExercisePlanLoading extends ExercisePlanState {
  const ExercisePlanLoading();
}

class ExercisePlanLoaded extends ExercisePlanState {
  final List<dynamic> exercises;
  const ExercisePlanLoaded(this.exercises);
}

class ExercisePlanError extends ExercisePlanState {
  final String message;
  const ExercisePlanError(this.message);
}
