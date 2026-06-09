import { defineConfig } from 'vite';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

export default defineConfig({
  build: {
    emptyOutDir: true,
    outDir: resolve(__dirname, '../../../html/vendor/a2ui'),
    lib: {
      entry: resolve(__dirname, 'src/official-a2ui/standalone-entry.ts'),
      name: 'NmerOfficialA2UIBundle',
      formats: ['iife'],
      fileName: () => 'nmer-a2ui-v09.js',
    },
    minify: 'esbuild',
    sourcemap: false,
  },
});
