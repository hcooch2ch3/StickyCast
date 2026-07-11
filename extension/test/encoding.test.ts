import { describe, it, expect } from "vitest";
import { toBase64URL, buildStickyURL, URL_PREFIX } from "../src/encoding";

describe("toBase64URL", () => {
  it("공용 테스트 벡터: 한글+이모지 (url-scheme-spec.md)", () => {
    expect(toBase64URL("안녕🎉")).toBe("7JWI64WV8J-OiQ");
  });
  it("ASCII", () => {
    expect(toBase64URL("hi")).toBe("aGk"); // 패딩 제거 확인
  });
  it("공용 테스트 벡터: multibyte + _ 포함 (가장 취약한 _→/ 역변환 경로)", () => {
    expect(toBase64URL("읽기???")).toBe("7J296riwPz8_");
  });
  it("출력에 +, /, = 미포함", () => {
    const out = toBase64URL("긴 한글 텍스트와 emoji 🎉🎉🎉 조합 ///+++");
    expect(out).not.toMatch(/[+/=]/);
  });
});

describe("buildStickyURL", () => {
  it("프리픽스 + base64url 결합", () => {
    expect(buildStickyURL("안녕🎉", 1000)).toBe(URL_PREFIX + "7JWI64WV8J-OiQ");
  });
  it("한도 초과 시 null", () => {
    expect(buildStickyURL("a".repeat(100), 50)).toBeNull();
  });
});
