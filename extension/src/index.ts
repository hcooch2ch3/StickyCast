import type { MarkEdit as MarkEditAPI } from "markedit-api";
import { buildStickyURL } from "./encoding";
import { MAX_CONTENT_BYTES } from "./limits";

declare const MarkEdit: MarkEditAPI;

// 한도 초과 안내 문구는 상수에서 파생 (하드코딩 재발 방지, iter 리뷰).
const MAX_MB = Math.round(MAX_CONTENT_BYTES / (1024 * 1024));

// 멱등 등록 가드: MarkEdit은 확장 스크립트를 웹뷰 컨텍스트당 로드해 같은 스크립트가
// 여러 번 실행될 수 있다 (pre-flight 2단계 실측). 전역 센티널로 중복 메뉴 등록을 막는다.
const g = globalThis as unknown as { __stickyCastRegistered?: boolean };
if (!g.__stickyCastRegistered) {
  g.__stickyCastRegistered = true;

  MarkEdit.addMainMenuItem([{
    title: "Pop as Sticky",
    action: () => {
      // 선택 영역이 있으면 그것을, 없으면 문서 전체를 스티커로.
      // 역방향 선택(to<from)도 지원하도록 to !== from 으로 거르고, 추출은 정렬된 range로.
      const ranges = MarkEdit.editorAPI.getSelections().filter((r) => r.to !== r.from);
      const hasSelection = ranges.length > 0;
      const content = hasSelection
        ? ranges
            .map((r) => MarkEdit.editorAPI.getText({ from: Math.min(r.from, r.to), to: Math.max(r.from, r.to) }))
            .join("\n\n")
        : MarkEdit.editorAPI.getText(); // range 생략 → 문서 전체

      if (content.length === 0) {
        void MarkEdit.showAlert({
          title: "띄울 내용이 없습니다",
          message: "문서가 비어 있습니다. 내용을 입력하거나 일부를 선택한 뒤 다시 시도하세요.",
        });
        return;
      }

      // 콘텐츠 한도(원문 바이트) 초과면 자르지 않고 거부 + 안내 (§7 조용한 실패 금지 / 잘림 없음).
      const url = buildStickyURL(content, MAX_CONTENT_BYTES);
      if (url === null) {
        void MarkEdit.showAlert({
          title: hasSelection ? "선택 영역이 너무 큽니다" : "문서가 너무 큽니다",
          message: `스티커는 약 ${MAX_MB}MB까지만 담을 수 있습니다. 원하는 부분만 선택한 뒤 다시 시도하세요.`,
        });
        return;
      }
      window.location.href = url;
    },
  }]);
}
