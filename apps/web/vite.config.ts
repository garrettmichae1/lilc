import { defineConfig } from "vitest/config";

export default defineConfig({
  // Relative URLs so GitHub project Pages can host at /lilc/web/
  base: "./",
  publicDir: "public",
  build: {
    outDir: "dist",
    emptyOutDir: true,
    sourcemap: true,
    assetsDir: "assets",
    target: "es2022",
  },
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
  },
});
