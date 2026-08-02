import { describe, it, expect } from "vitest";
import { deriveContent, type Sel, type Pos } from "../../obsidian/src/derive";

const getRange = (f: Pos, t: Pos) => `<${f.line},${f.ch}..${t.line},${t.ch}>`;
const whole = () => "WHOLE_DOC";
const sel = (a: [number, number], h: [number, number]): Sel =>
  ({ anchor: { line: a[0], ch: a[1] }, head: { line: h[0], ch: h[1] } });

describe("deriveContent", () => {
  it("no selections -> whole document", () => {
    expect(deriveContent([], getRange, whole)).toBe("WHOLE_DOC");
  });
  it("single caret (zero-width) -> whole document", () => {
    expect(deriveContent([sel([1, 2], [1, 2])], getRange, whole)).toBe("WHOLE_DOC");
  });
  it("single selection -> getRange once", () => {
    expect(deriveContent([sel([0, 0], [0, 4])], getRange, whole)).toBe("<0,0..0,4>");
  });
  it("reversed selection is normalized (from before to)", () => {
    expect(deriveContent([sel([2, 5], [1, 0])], getRange, whole)).toBe("<1,0..2,5>");
  });
  it("multiple selections joined with blank line in document order", () => {
    const out = deriveContent([sel([5, 0], [5, 3]), sel([1, 0], [1, 2])], getRange, whole);
    expect(out).toBe("<1,0..1,2>\n\n<5,0..5,3>");
  });
  it("drops zero-width among real selections", () => {
    const out = deriveContent([sel([1, 1], [1, 1]), sel([2, 0], [2, 2])], getRange, whole);
    expect(out).toBe("<2,0..2,2>");
  });
});
