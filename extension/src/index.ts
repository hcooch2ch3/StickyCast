// markedit-api의 런타임 export는 빈 스텁(Object.freeze({}))이라 번들하면 안 된다.
// 실제 MarkEdit은 런타임 전역으로 주입되므로, 타입만 가져오고 전역을 declare로 참조한다.
import type { MarkEdit as MarkEditAPI } from "markedit-api";
import { buildStickyURL } from "./encoding";
import { MAX_URL_LENGTH } from "./limits";

declare const MarkEdit: MarkEditAPI;

// 멱등 등록 가드: MarkEdit은 확장 스크립트를 웹뷰 컨텍스트당 로드해 같은 스크립트가
// 여러 번 실행될 수 있다 (pre-flight 2단계 실측: 5회). 전역 센티널로 중복 메뉴 등록을 막는다.
const g = globalThis as unknown as { __stickyCastRegistered?: boolean };
if (!g.__stickyCastRegistered) {
  g.__stickyCastRegistered = true;

  MarkEdit.addMainMenuItem([{
    title: "Pop as Sticky",
    action: () => {
      // 선택 취득: getSelections()는 TextRange[](다중 선택). 빈 범위(from==to) 제외 후 각 구간을 getText로.
      const ranges = MarkEdit.editorAPI.getSelections().filter((r) => r.to > r.from);
      if (ranges.length === 0) return; // 빈 선택: 무시 (§7)
      const selection = ranges.map((r) => MarkEdit.editorAPI.getText(r)).join("\n\n");

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
