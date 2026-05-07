import { defineConfig } from "vite";

export default defineConfig({
  clearScreen: false,
  server: {
    strictPort: true,
    port: 34116,
  },
  build: {
    outDir: "dist",
  },
});
