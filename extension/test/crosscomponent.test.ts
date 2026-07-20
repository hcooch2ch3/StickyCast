import { describe, it, expect } from "vitest";
import fixturesRoot from "../../fixtures/roundtrip.json";
import { toBase64URL, buildStickyURL, URL_PREFIX } from "../src/encoding";

// 하나의 기계 생성 소스(fixtures/roundtrip.json)를 확장·앱 테스트가 함께 소비한다.
// 앱 측 대응 테스트: app/Tests/StickyCastTests/CrossComponentTests.swift (같은 파일을 읽어 파서로 복원 검증).
interface Fixture { input: string; encoded: string; note?: string; }
const fixtures = (fixturesRoot as { fixtures: Fixture[] }).fixtures;

// 앱 파서와도, 인코더와도 독립적인 base64url 디코더 (DOM atob + TextDecoder).
// 인코더 출력이 '제3의 디코더'로도 원문을 복원함을 증명 → 벡터가 틀렸는데 양쪽이 같이 통과하는 리스크 제거.
function independentDecode(b64url: string): string {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  const bytes = Uint8Array.from(bin, (ch) => ch.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

describe("크로스-컴포넌트 왕복 픽스처 (fixtures/roundtrip.json)", () => {
  it("픽스처가 비어있지 않다 (경로/로드 회귀 가드)", () => {
    expect(fixtures.length).toBeGreaterThan(0);
  });

  for (const { input, encoded, note } of fixtures) {
    it(`인코더가 픽스처 encoded를 재현: ${note ?? input}`, () => {
      // 실제 확장 인코더가 기계 생성 encoded와 바이트 단위로 일치해야 함.
      expect(toBase64URL(input)).toBe(encoded);
      expect(buildStickyURL(input, 10 * 1024 * 1024)).toBe(URL_PREFIX + encoded);
    });

    it(`독립 디코더 왕복(인코더 신뢰 제거): ${note ?? input}`, () => {
      // toBase64URL 출력 → 제3의 디코더 → 원문. 리터럴을 믿지 않고 인코더 정확성 자체를 증명.
      expect(independentDecode(toBase64URL(input))).toBe(input);
    });
  }
});
