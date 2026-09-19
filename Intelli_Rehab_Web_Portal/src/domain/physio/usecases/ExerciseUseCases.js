import ExerciseRepository from "../../../infrastructure/physio/repositories/ExerciseRepository";

class ExerciseUseCases {
  getAllExercises() {
    return ExerciseRepository.getAll();
  }

  getExerciseById(id) {
    return ExerciseRepository.getById(id);
  }

  getExercisesByDifficulty(difficulty) {
    return ExerciseRepository.getByDifficulty(difficulty);
  }

  searchExercises(query) {
    return ExerciseRepository.search(query);
  }

  filterExercises(difficulty, query) {
    return ExerciseRepository.filter(difficulty, query);
  }

  getDifficultyLevels() {
    return ["All", "Beginner", "Intermediate", "Advanced"];
  }

  getTotalExerciseCount() {
    return ExerciseRepository.getAll().length;
  }
}

export default new ExerciseUseCases();
