// sticky:// content 인코딩 (docs/url-scheme-spec.md 계약)
export const URL_PREFIX = "sticky://new?content=";

/** UTF-8 → base64url (RFC 4648 §5, 패딩 없음). btoa(원문) 금지 — 계약 문서 참조. */
export function toBase64URL(input: string): string {
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b); // 각 문자 ≤ 0xFF → btoa 안전
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** 인코딩된 URL이 한도 초과면 null (호출부가 알림 표시). */
export function buildStickyURL(selection: string, maxURLLength: number): string | null {
  const url = URL_PREFIX + toBase64URL(selection);
  return url.length > maxURLLength ? null : url;
}
