import type { MarkEdit as MarkEditAPI } from "markedit-api";
import { buildStickyURL } from "./encoding";
import { MAX_URL_LENGTH } from "./limits";

declare const MarkEdit: MarkEditAPI;

// 멱등 등록 가드: MarkEdit은 확장 스크립트를 웹뷰 컨텍스트당 로드해 같은 스크립트가
// 여러 번 실행될 수 있다 (pre-flight 2단계 실측). 전역 센티널로 중복 메뉴 등록을 막는다.
const g = globalThis as unknown as { __stickyCastRegistered?: boolean };
if (!g.__stickyCastRegistered) {
  g.__stickyCastRegistered = true;

  MarkEdit.addMainMenuItem([{
    title: "Pop as Sticky",
    action: () => {
      // 선택 취득: 빈 범위(from==to, 커서) 제외. 역방향 선택(to<from)도 지원하도록
      // to !== from 로 거르고, 추출은 정렬된 range로 (iter-006 리뷰 반영).
      const ranges = MarkEdit.editorAPI.getSelections().filter((r) => r.to !== r.from);
      const selection = ranges
        .map((r) => MarkEdit.editorAPI.getText({ from: Math.min(r.from, r.to), to: Math.max(r.from, r.to) }))
        .join("\n\n");

      if (selection.length === 0) {
        // 빈 선택: 조용히 무시하지 않고 안내 (사용자 혼란 방지 — "아무것도 안 나옴"). §7 UX 개선.
        void MarkEdit.showAlert({
          title: "선택된 텍스트가 없습니다",
          message: "스티커로 띄울 마크다운을 먼저 드래그해서 선택한 뒤 Pop as Sticky를 누르세요.",
        });
        return;
      }

      const url = buildStickyURL(selection, MAX_URL_LENGTH);
      if (url === null) {
        // 한도 초과: 네이티브 알럿으로 알림 (fire-and-forget). window.alert 금지 — §7.
        void MarkEdit.showAlert({
          title: "선택 영역이 너무 큽니다",
          message: "더 짧게 선택한 뒤 다시 시도해 주세요.",
        });
        return;
      }
      window.location.href = url;
    },
  }]);
}
