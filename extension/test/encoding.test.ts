import { describe, it, expect } from "vitest";
import { toBase64URL, buildStickyURL, URL_PREFIX } from "../src/encoding";

describe("toBase64URL", () => {
  it("shared test vector: Korean + emoji (url-scheme-spec.md)", () => {
    expect(toBase64URL("안녕🎉")).toBe("7JWI64WV8J-OiQ");
  });
  it("ASCII", () => {
    expect(toBase64URL("hi")).toBe("aGk"); // confirm padding is stripped
  });
  it("shared test vector: multibyte incl. _ (the most fragile _→/ reverse path)", () => {
    expect(toBase64URL("읽기???")).toBe("7J296riwPz8_");
  });
  it("output contains no +, /, or =", () => {
    const out = toBase64URL("긴 한글 텍스트와 emoji 🎉🎉🎉 조합 ///+++");
    expect(out).not.toMatch(/[+/=]/);
  });
});

describe("buildStickyURL (limit is by raw bytes)", () => {
  it("prefix + base64url combined (within limit)", () => {
    expect(buildStickyURL("안녕🎉", 1000)).toBe(URL_PREFIX + "7JWI64WV8J-OiQ");
  });
  it("null when over the raw-byte limit (reject, do not truncate)", () => {
    expect(buildStickyURL("a".repeat(100), 50)).toBeNull(); // 100 bytes > 50
  });
  it("limit boundary: exactly at limit allowed, 1 byte over is null", () => {
    expect(buildStickyURL("a".repeat(50), 50)).not.toBeNull(); // 50 == 50 allowed
    expect(buildStickyURL("a".repeat(51), 50)).toBeNull();     // 51 > 50 rejected
  });
  it("multibyte judged by bytes, not char count (Korean is 3 bytes)", () => {
    expect(buildStickyURL("가", 2)).toBeNull();        // "가" = 3 bytes > 2
    expect(buildStickyURL("가", 3)).not.toBeNull();    // 3 == 3 allowed
  });
});
