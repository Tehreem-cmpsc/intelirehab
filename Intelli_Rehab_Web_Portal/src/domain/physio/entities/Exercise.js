export class Exercise {
  constructor({ id, name, target, difficulty, desc }) {
    this.id = id;
    this.name = name;
    this.target = target;
    this.difficulty = difficulty; // 'Beginner', 'Intermediate', 'Advanced'
    this.desc = desc;
  }

  isDifficulty(level) {
    return this.difficulty === level;
  }

  matches(searchQuery) {
    const query = searchQuery.toLowerCase();
    return (
      this.name.toLowerCase().includes(query) ||
      this.target.toLowerCase().includes(query)
    );
  }
}
