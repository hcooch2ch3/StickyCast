// preflight/test-length-auto.js — URL 길이 실측 자동판: 에디터 로드 시 크기별 순차 자동 발사
// 주의: 측정 후 반드시 scripts/에서 제거할 것 (에디터 열 때마다 발사됨)
const fire = (urlLen) => {
  const prefix = "sticky://new?content=";
  const payload = "A".repeat(urlLen - prefix.length);
  window.location.href = prefix + payload;
};
const sizes = [1, 8, 43, 128]; // KB
sizes.forEach((kb, i) => {
  setTimeout(() => fire(kb * 1024), 2000 + i * 1500);
});
