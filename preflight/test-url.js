// preflight/test-url.js — MarkEdit 확장: 외부 URL 네비게이션 가능 여부 검증
// 변형: A/C/D는 location.href (스킴만 다름), B는 window.open.
// - A(https): 웹 스킴 외부 핸드오프. WebKit이 자체 렌더 가능한 스킴이라 커스텀 스킴 증거로는 불충분.
// - D(obsidian://): 비웹 커스텀 스킴 핸드오프 — sticky://가 탈 경로와 동일 계열. 1단계의 핵심 신호.
// - C(mailto): 이 Mac에서 OS 레벨 핸들러가 깨져 있어 판정 지표에서 제외 (참고용 유지).
// - B(window.open): WKWebView에서 호스트 미구현 시 무반응이라 진단 가치 낮음 (참고용 유지).
MarkEdit.addMainMenuItem([
  {
    title: "Pre-flight A: https via location.href",
    action: () => { window.location.href = "https://example.com/?preflight=href"; }
  },
  {
    title: "Pre-flight B: https via window.open",
    action: () => { window.open("https://example.com/?preflight=open"); }
  },
  {
    title: "Pre-flight C: mailto via location.href",
    action: () => { window.location.href = "mailto:test@example.com"; }
  },
  {
    title: "Pre-flight D: obsidian:// via location.href",
    action: () => { window.location.href = "obsidian://"; }
  }
]);
