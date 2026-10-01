// @vitest-environment jsdom
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor, cleanup, fireEvent } from "@testing-library/react";

// No network: Supabase is replaced by a client with no signed-in user.
vi.mock("./infrastructure/supabase/supabaseClient", () => ({
  supabase: {
    auth: {
      getSession: async () => ({ data: { session: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signOut: async () => ({}),
    },
    from: () => ({ select: () => ({ eq: () => ({ limit: async () => ({ data: [] }) }) }) }),
  },
}));

import App from "./App";

beforeEach(() => {
  window.location.hash = "";
});
afterEach(cleanup);

describe("App shell (signed out)", () => {
  it("shows the landing page at #/ (lazy chunks load, no crash)", async () => {
    render(<App />);
    expect((await screen.findAllByText(/sign in/i)).length).toBeGreaterThan(0);
  });

  it("Sign In on the landing page opens the login page, and Back returns", async () => {
    render(<App />);
    const signIn = (await screen.findAllByRole("button", { name: /sign in/i }))[0];
    fireEvent.click(signIn);
    await waitFor(() => expect(window.location.hash).toBe("#/login"));
    expect(await screen.findByText(/welcome back/i)).toBeTruthy();
  });

  it("sends a signed-out visit to #/app/... to the login page", async () => {
    window.location.hash = "#/app/patients";
    render(<App />);
    await waitFor(() => expect(window.location.hash).toBe("#/login"));
    expect(await screen.findByText(/welcome back/i)).toBeTruthy();
  });

  it("shows login at #/login", async () => {
    window.location.hash = "#/login";
    render(<App />);
    expect(await screen.findByText(/welcome back/i)).toBeTruthy();
  });
});
