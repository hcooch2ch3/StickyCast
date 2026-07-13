// extension/src/limits.ts — URL 길이 한도 (docs/preflight-results.md 실측 근거). 수기 추정치 금지.
// 실측(2026-07): MarkEdit(WebKit)→OS→앱 경로로 URL 32MB까지 무손실 수신, 64MB에서 드롭.
// 확인된 안전 천장 32MB를 URL 상한으로 채택 (원문 예산 ≈ 32MB × 3/4 ≈ 24MB — base64 팽창 반영).
// 주의: 이 값을 올리면 32~64MB 미검증 구간에 들어가 조용한 드롭 위험.
export const MAX_URL_LENGTH = 32 * 1024 * 1024;
