class AuthService {
  constructor() {
    this.token = null;
    this.user = null;
  }

  setToken(token) {
    this.token = token;
    localStorage.setItem("auth_token", token);
  }

  getToken() {
    return this.token || localStorage.getItem("auth_token");
  }

  setUser(user) {
    this.user = user;
    localStorage.setItem("user", JSON.stringify(user));
  }

  getUser() {
    return this.user || JSON.parse(localStorage.getItem("user") || "null");
  }

  logout() {
    this.token = null;
    this.user = null;
    localStorage.removeItem("auth_token");
    localStorage.removeItem("user");
  }

  isAuthenticated() {
    return !!this.getToken();
  }
}

export default new AuthService();
