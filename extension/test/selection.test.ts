import { describe, it, expect, vi } from "vitest";
import { deriveContent, type TextRange } from "../src/selection";

// getText 스텁: range 있으면 "TEXT[from,to]", 없으면 문서 전체 마커. deriveContent가 무엇을 호출하는지 검증.
function makeGetText(whole = "WHOLE-DOC") {
  return vi.fn((range?: TextRange) =>
    range ? `T[${range.from},${range.to}]` : whole,
  );
}

describe("deriveContent (index.ts 선택 파생 로직)", () => {
  it("선택 없음 → 문서 전체(getText())", () => {
    const getText = makeGetText();
    expect(deriveContent([], getText)).toBe("WHOLE-DOC");
    expect(getText).toHaveBeenCalledWith(); // range 없이 호출
  });

  it("폭 0 선택(캐럿)만 있으면 → 문서 전체", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 5, to: 5 }], getText)).toBe("WHOLE-DOC");
    expect(getText).toHaveBeenCalledWith();
  });

  it("단일 정방향 선택 → 그 range 추출", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 2, to: 7 }], getText)).toBe("T[2,7]");
  });

  it("역방향 선택(to<from) → 정렬해서 추출", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 9, to: 3 }], getText)).toBe("T[3,9]");
  });

  it("다중 선택 → \\n\\n 결합 (폭 0은 제외)", () => {
    const getText = makeGetText();
    const out = deriveContent(
      [{ from: 1, to: 4 }, { from: 10, to: 10 }, { from: 20, to: 15 }],
      getText,
    );
    expect(out).toBe("T[1,4]\n\nT[15,20]"); // 캐럿 제외, 역방향 정렬
    expect(getText).not.toHaveBeenCalledWith(); // 선택이 있으므로 문서 전체 호출 안 함
  });
});
