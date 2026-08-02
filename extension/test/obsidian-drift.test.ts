import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const names = ["encoding.ts", "limits.ts"] as const;

describe("obsidian/src copies are byte-identical to extension/src", () => {
  for (const name of names) {
    it(`${name} matches`, () => {
      const orig = readFileSync(new URL(`../src/${name}`, import.meta.url));
      const copy = readFileSync(new URL(`../../obsidian/src/${name}`, import.meta.url));
      expect(copy.equals(orig)).toBe(true);
    });
  }
});
