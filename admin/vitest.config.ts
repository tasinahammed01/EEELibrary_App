import { defineConfig } from "vitest/config";
export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./test/setup.ts"],
    maxWorkers: 1,
    testTimeout: 15000,
  },
});
