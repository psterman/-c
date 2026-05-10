import { defineConfig } from "vite";
import { resolve } from "path";

export default defineConfig({
  clearScreen: false,
  server: {
    host: "127.0.0.1",
    strictPort: true,
    port: 5173,
  },
  build: {
    outDir: "dist",
    rollupOptions: {
      input: {
        main: resolve(__dirname, "index.html"),
        hole: resolve(__dirname, "hole.html"),
        hole_starry: resolve(__dirname, "hole_starry.html"),
      },
    },
  },
});


