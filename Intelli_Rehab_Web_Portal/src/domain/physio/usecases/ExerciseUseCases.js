import ExerciseRepository from "../../../infrastructure/physio/repositories/ExerciseRepository";

class ExerciseUseCases {
  // Loaded once by whichever screen needs the catalogue (ExercisesPage,
  // the assign-session picker) and filtered client-side from there —
  // there aren't enough rows for this to need a server-side query per
  // keystroke.
  getAllExercises() {
    return ExerciseRepository.getAll();
  }

  filterExercises(exercises, difficulty, query) {
    return ExerciseRepository.filter(exercises, difficulty, query);
  }

  getDifficultyLevels() {
    return ["All", "Beginner", "Intermediate", "Advanced"];
  }
}

export default new ExerciseUseCases();
