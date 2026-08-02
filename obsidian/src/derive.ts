// Pure content derivation — NO "obsidian" import, so the extension vitest can test it
// without the Obsidian runtime. Obsidian's EditorSelection/EditorPosition are structurally
// compatible with Sel/Pos, so main.ts passes editor.listSelections() directly.
export interface Pos { line: number; ch: number; }
export interface Sel { anchor: Pos; head: Pos; }

function cmp(a: Pos, b: Pos): number {
  return a.line !== b.line ? a.line - b.line : a.ch - b.ch;
}

/**
 * Selections -> the sticky content.
 * - Reversed selections (head before anchor) are normalized to from..to.
 * - Zero-width selections (carets) are dropped.
 * - Remaining selections are ordered by document position and joined with "\n\n".
 *   (Document order; the MarkEdit extension relies on CodeMirror's implicit order instead,
 *   so the output matches but the algorithm differs — this sort makes the port order-robust.)
 * - If nothing non-empty is selected, return the whole document.
 */
export function deriveContent(
  selections: readonly Sel[],
  getRange: (from: Pos, to: Pos) => string,
  getValue: () => string,
): string {
  const ranges = selections
    .map((s) => (cmp(s.anchor, s.head) <= 0 ? { from: s.anchor, to: s.head } : { from: s.head, to: s.anchor }))
    .filter((r) => cmp(r.from, r.to) !== 0)
    .sort((a, b) => cmp(a.from, b.from));
  if (ranges.length === 0) return getValue();
  return ranges.map((r) => getRange(r.from, r.to)).join("\n\n");
}
