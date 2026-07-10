// extension/src/limits.ts — Task 2 pre-flight 실측치 (docs/preflight-results.md 근거). 수기 추정치 금지.
// 실측(2026-07-11): MarkEdit(WebKit) 경유 128KB, 터미널 경유 256KB까지 무손실 수신 — 실패 지점 미발견.
// 43KB는 전송 한계가 아니라 제품 한도(스티커 = 짧은 메모, 원문 약 32KB)이며 실측 대비 3배 여유.
export const MAX_URL_LENGTH = 43 * 1024;
