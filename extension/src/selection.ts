// index.ts의 선택→콘텐츠 파생 로직 (MarkEdit 전역 없이 단위 테스트 가능하도록 순수 함수로 분리).
// markedit-api getText 시그니처: getText(range?: TextRange) — range 생략 시 문서 전체 (docs/markedit-api-notes.md).

export interface TextRange {
  readonly from: number;
  readonly to: number;
}

/**
 * 선택 영역들 → 스티커에 담을 콘텐츠 문자열.
 * - 유효 선택(폭 > 0)이 하나도 없으면 문서 전체(`getText()`)를 반환.
 * - 역방향 선택(to < from)은 정렬해 추출 (Math.min/max).
 * - 폭 0 선택(캐럿)은 제외.
 * - 다중 선택은 `"\n\n"`으로 결합.
 */
export function deriveContent(
  selections: readonly TextRange[],
  getText: (range?: TextRange) => string,
): string {
  const ranges = selections.filter((r) => r.to !== r.from);
  if (ranges.length === 0) return getText(); // 문서 전체
  return ranges
    .map((r) => getText({ from: Math.min(r.from, r.to), to: Math.max(r.from, r.to) }))
    .join("\n\n");
}
