// preflight/test-length.js — URL 길이 한계 실측 (측정 대상: 인코딩된 URL 전체 길이)
const fire = (urlLen) => {
  const prefix = "sticky://new?content=";
  const payload = "A".repeat(urlLen - prefix.length); // 'A'는 유효 base64url 문자
  window.location.href = prefix + payload;
};
MarkEdit.addMainMenuItem([
  { title: "Pre-flight: sticky 1KB URL",   action: () => fire(1024) },
  { title: "Pre-flight: sticky 8KB URL",   action: () => fire(8 * 1024) },
  { title: "Pre-flight: sticky 43KB URL",  action: () => fire(43 * 1024) },
  { title: "Pre-flight: sticky 128KB URL", action: () => fire(128 * 1024) },
]);
