import { describe, it, expect } from "vitest";
import { detectLang, t } from "../src/i18n";

describe("detectLang (primary-subtag exact match)", () => {
  it("ko / ko-KR → ko", () => {
    expect(detectLang("ko")).toBe("ko");
    expect(detectLang("ko-KR")).toBe("ko");
  });
  it("kok / kos / other / undefined → en", () => {
    expect(detectLang("kok")).toBe("en");
    expect(detectLang("kos")).toBe("en");
    expect(detectLang("en-US")).toBe("en");
    expect(detectLang("fr")).toBe("en");
    expect(detectLang(undefined)).toBe("en");
  });
});

describe("t (resolver)", () => {
  it("resolves every key in both languages", () => {
    for (const lang of ["en", "ko"] as const) {
      const m = t(lang, 1);
      for (const v of Object.values(m)) expect(typeof v).toBe("string");
    }
  });
  it("interpolates MB into the too-large body", () => {
    expect(t("en", 1).tooLargeBody).toContain("1MB");
  });
});
