// Selection → content derivation from index.ts (split out as a pure function so it can be unit-tested without the MarkEdit global).
// markedit-api getText signature: getText(range?: TextRange). Omit range to get the whole document (docs/markedit-api-notes.md).

export interface TextRange {
  readonly from: number;
  readonly to: number;
}

/**
 * Selections → the content string that goes into the sticky.
 * - If there's no valid selection (width > 0), return the whole document (`getText()`).
 * - Reversed selections (to < from) are normalized before extraction (Math.min/max).
 * - Zero-width selections (carets) are dropped.
 * - Multiple selections are joined with `"\n\n"`.
 */
export function deriveContent(
  selections: readonly TextRange[],
  getText: (range?: TextRange) => string,
): string {
  const ranges = selections.filter((r) => r.to !== r.from);
  if (ranges.length === 0) return getText(); // whole document
  return ranges
    .map((r) => getText({ from: Math.min(r.from, r.to), to: Math.max(r.from, r.to) }))
    .join("\n\n");
}
