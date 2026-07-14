// sticky:// content 인코딩 (docs/url-scheme-spec.md 계약)
export const URL_PREFIX = "sticky://new?content=";

function bytesToBase64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b); // 각 문자 ≤ 0xFF → btoa 안전
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** UTF-8 → base64url (RFC 4648 §5, 패딩 없음). btoa(원문) 금지 — 계약 문서 참조. */
export function toBase64URL(input: string): string {
  return bytesToBase64URL(new TextEncoder().encode(input));
}

/**
 * 원문 바이트가 콘텐츠 한도 초과면 null (호출부가 알림). 한도는 URL 길이가 아니라 원문 바이트 기준 —
 * 전송(URL)은 32MB까지 열려 있으나 저장(UserDefaults)·렌더링 부담을 막기 위해 콘텐츠 예산을 별도로 둔다.
 * 크기 검사를 base64 인코딩 前에 수행해 초과 입력에서 메인스레드 스톨을 방지한다 (iter 리뷰).
 */
export function buildStickyURL(content: string, maxContentBytes: number): string | null {
  const bytes = new TextEncoder().encode(content);
  if (bytes.length > maxContentBytes) return null;
  return URL_PREFIX + bytesToBase64URL(bytes);
}
