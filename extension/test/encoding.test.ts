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

describe("buildStickyURL (한도는 원문 바이트 기준)", () => {
  it("프리픽스 + base64url 결합 (한도 내)", () => {
    expect(buildStickyURL("안녕🎉", 1000)).toBe(URL_PREFIX + "7JWI64WV8J-OiQ");
  });
  it("원문 바이트 한도 초과 시 null (자르지 않고 거부)", () => {
    expect(buildStickyURL("a".repeat(100), 50)).toBeNull(); // 100바이트 > 50
  });
  it("한도 경계: 정확히 한도면 허용, 1바이트 초과면 null", () => {
    expect(buildStickyURL("a".repeat(50), 50)).not.toBeNull(); // 50 == 50 허용
    expect(buildStickyURL("a".repeat(51), 50)).toBeNull();     // 51 > 50 거부
  });
  it("멀티바이트는 문자 수가 아닌 바이트로 판정 (한글 3바이트)", () => {
    expect(buildStickyURL("가", 2)).toBeNull();        // "가" = 3바이트 > 2
    expect(buildStickyURL("가", 3)).not.toBeNull();    // 3 == 3 허용
  });
});
