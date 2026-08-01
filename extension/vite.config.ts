// The lib IIFE build is already a single file (no need for vite-plugin-singlefile, which is HTML-only)
import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: { entry: "src/index.ts", formats: ["iife"], name: "StickyCast", fileName: () => "sticky-cast" },
    outDir: "dist",
    rollupOptions: { output: { entryFileNames: "sticky-cast.js" } }
  }
});
