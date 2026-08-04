import { describe, it, expect, vi } from "vitest";
import { deriveContent, type TextRange } from "../src/selection";

// getText stub: returns "TEXT[from,to]" when given a range, otherwise a whole-document marker. Verifies what deriveContent calls.
function makeGetText(whole = "WHOLE-DOC") {
  return vi.fn((range?: TextRange) =>
    range ? `T[${range.from},${range.to}]` : whole,
  );
}

describe("deriveContent (index.ts selection-derivation logic)", () => {
  it("no selection → whole document (getText())", () => {
    const getText = makeGetText();
    expect(deriveContent([], getText)).toBe("WHOLE-DOC");
    expect(getText).toHaveBeenCalledWith(); // called without a range
  });

  it("only a zero-width selection (caret) → whole document", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 5, to: 5 }], getText)).toBe("WHOLE-DOC");
    expect(getText).toHaveBeenCalledWith();
  });

  it("single forward selection → extract that range", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 2, to: 7 }], getText)).toBe("T[2,7]");
  });

  it("reverse selection (to<from) → sort then extract", () => {
    const getText = makeGetText();
    expect(deriveContent([{ from: 9, to: 3 }], getText)).toBe("T[3,9]");
  });

  it("multiple selections → joined by \\n\\n (zero-width excluded)", () => {
    const getText = makeGetText();
    const out = deriveContent(
      [{ from: 1, to: 4 }, { from: 10, to: 10 }, { from: 20, to: 15 }],
      getText,
    );
    expect(out).toBe("T[1,4]\n\nT[15,20]"); // caret dropped, reversed range normalized
    expect(getText).not.toHaveBeenCalledWith(); // a selection exists, so it never asks for the whole document
  });
});
