import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Pure-logic tests need no DOM; component smoke tests opt in with
    // `// @vitest-environment jsdom` at the top of the file.
    environment: "node",
  },
});
