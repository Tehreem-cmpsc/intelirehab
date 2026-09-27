import 'exercise_plan_state.dart';

class ExercisePlanCubit {
  ExercisePlanState _state = const ExercisePlanInitial();
  ExercisePlanState get state => _state;

  void emit(ExercisePlanState newState) {
    _state = newState;
  }

  void loadExercisePlan() {}
}
