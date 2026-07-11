// lib IIFE 빌드는 그 자체로 단일 파일 (vite-plugin-singlefile 불필요 — HTML 전용 플러그인)
import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: { entry: "src/index.ts", formats: ["iife"], name: "StickyCast", fileName: () => "sticky-cast" },
    outDir: "dist",
    rollupOptions: { output: { entryFileNames: "sticky-cast.js" } }
  }
});
