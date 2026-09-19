// Mock API Client - In production, this would connect to real backend
class ApiClient {
  constructor() {
    this.baseUrl = process.env.REACT_APP_API_URL || "http://localhost:3000/api";
  }

  async authenticate(id, password) {
    // Mock implementation - in production would call actual API
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        if (id && password) {
          resolve({
            success: true,
            token: "mock-jwt-token",
            user: { id, role: "physiotherapist" },
          });
        } else {
          reject(new Error("Invalid credentials"));
        }
      }, 900);
    });
  }

  async getPatients() {
    // Mock implementation
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({ success: true, data: [] });
      }, 300);
    });
  }

  async updatePatient(patientId, data) {
    // Mock implementation
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({ success: true, data });
      }, 200);
    });
  }

  async getExercises() {
    // Mock implementation
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({ success: true, data: [] });
      }, 300);
    });
  }

  // Future: Add more API endpoints
}

export default new ApiClient();
