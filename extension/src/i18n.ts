export type Lang = "en" | "ko";

// Match the PRIMARY subtag exactly: "ko"/"ko-KR" → ko, "kok"/"kos"/other/undefined → en.
// Guard the default: in a Node/vitest env there is no `navigator`, so a bare
// detectLang() would throw ReferenceError. Tests always pass an arg and index.ts
// runs in the webview (navigator exists), but harden the default anyway.
export function detectLang(
  nav: string | undefined = typeof navigator !== "undefined" ? navigator.language : undefined,
): Lang {
  return nav?.split("-")[0] === "ko" ? "ko" : "en";
}

// Every entry is a function of (mb) so t() never branches value-vs-function.
export const messages = {
  emptyTitle: (_mb: number) => ({ en: "Nothing to pop", ko: "띄울 내용이 없습니다" }),
  emptyBody: (_mb: number) => ({
    en: "The document is empty or whitespace only. Type or select something and try again.",
    ko: "문서가 비어 있거나 공백뿐입니다. 내용을 입력하거나 일부를 선택한 뒤 다시 시도하세요.",
  }),
  tooLargeTitleSel: (_mb: number) => ({ en: "Selection too large", ko: "선택 영역이 너무 큽니다" }),
  tooLargeTitleDoc: (_mb: number) => ({ en: "Document too large", ko: "문서가 너무 큽니다" }),
  tooLargeBody: (mb: number) => ({
    en: `A sticker holds about ${mb}MB max. Select the part you want and try again.`,
    ko: `스티커는 약 ${mb}MB까지만 담을 수 있습니다. 원하는 부분만 선택한 뒤 다시 시도하세요.`,
  }),
  unsavedTitle: (_mb: number) => ({ en: "Not saved yet", ko: "아직 저장 안 됨" }),
  unsavedBody: (_mb: number) => ({
    en: "This document has no file on disk, so the sticker can't stay in sync with it. Pop a snapshot instead?",
    ko: "이 문서는 아직 파일로 저장되지 않아 스티커가 파일과 동기화될 수 없습니다. 스냅샷(복사본)으로 띄울까요?",
  }),
  unsavedSnapshotBtn: (_mb: number) => ({ en: "Pop snapshot", ko: "스냅샷으로 띄우기" }),
  cancelBtn: (_mb: number) => ({ en: "Cancel", ko: "취소" }),
};

export function t(lang: Lang, mb: number) {
  return Object.fromEntries(
    Object.entries(messages).map(([k, f]) => [k, f(mb)[lang]]),
  ) as Record<keyof typeof messages, string>;
}
