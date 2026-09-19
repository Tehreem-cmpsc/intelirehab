import { EXERCISES } from "../constants";

class ExerciseRepository {
  constructor() {
    this.exercises = [...EXERCISES];
  }

  getAll() {
    return this.exercises;
  }

  getById(id) {
    return this.exercises.find((e) => e.id === id);
  }

  getByDifficulty(difficulty) {
    return this.exercises.filter((e) => e.difficulty === difficulty);
  }

  search(query) {
    return this.exercises.filter((e) => e.matches(query));
  }

  filter(difficulty, query) {
    let filtered = this.exercises;

    if (difficulty !== "All") {
      filtered = filtered.filter((e) => e.isDifficulty(difficulty));
    }

    if (query) {
      filtered = filtered.filter((e) => e.matches(query));
    }

    return filtered;
  }
}

export default new ExerciseRepository();
