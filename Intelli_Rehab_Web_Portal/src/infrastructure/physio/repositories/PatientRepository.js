import { PATIENTS, EXERCISES } from "../constants";

class PatientRepository {
  constructor() {
    this.patients = [...PATIENTS];
  }

  getAll() {
    return this.patients;
  }

  getById(id) {
    return this.patients.find((p) => p.id === id);
  }

  getPending() {
    return this.patients.filter((p) => !p.approved);
  }

  getAtRisk() {
    return this.patients.filter((p) => p.status === "at-risk");
  }

  getApproved() {
    return this.patients.filter((p) => p.approved);
  }

  approve(id) {
    const patient = this.getById(id);
    if (patient) {
      patient.approved = true;
      return patient;
    }
    return null;
  }

  reject(id) {
    this.patients = this.patients.filter((p) => p.id !== id);
    return true;
  }

  update(id, updates) {
    const patient = this.getById(id);
    if (patient) {
      Object.assign(patient, updates);
      return patient;
    }
    return null;
  }

  updateWarning(id, warning) {
    const patient = this.getById(id);
    if (patient) {
      patient.warning = warning;
      return patient;
    }
    return null;
  }

  assignExercise(id, exerciseData) {
    const patient = this.getById(id);
    if (patient) {
      patient.currentExercise = exerciseData;
      return patient;
    }
    return null;
  }
}

export default new PatientRepository();
