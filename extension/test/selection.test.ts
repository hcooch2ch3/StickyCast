import { describe, it, expect, vi } from "vitest";
import { deriveContent, type TextRange } from "../src/selection";

// getText stub: returns "TEXT[from,to]" when given a range, otherwise a whole-document marker. Verifies what deriveContent calls.
function makeGetText(whole = "WHOLE-DOC") {
  return vi.fn((range?: TextRange) =>
    range ? `T[${range.from},${range.to}]` : whole,
  );
}

describe("deriveContent (index.ts 선택 파생 로직)", () => {
  it("선택 없음 → 문서 전체(getText())", () => {
    const getText = makeGetText();
    expect(deriveContent([], getText)).toBe("WHOLE-DOC");
    expect(getText).toHaveBeenCalledWith(); // called without a range
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
    expect(out).toBe("T[1,4]\n\nT[15,20]"); // caret dropped, reversed range normalized
    expect(getText).not.toHaveBeenCalledWith(); // a selection exists, so it never asks for the whole document
  });
});
