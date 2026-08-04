import type { MarkEdit as MarkEditAPI } from "markedit-api";
import { buildStickyURL } from "./encoding";
import { deriveContent } from "./selection";
import { MAX_CONTENT_BYTES } from "./limits";
import { detectLang, t } from "./i18n";

declare const MarkEdit: MarkEditAPI;

// Derive the over-limit message from the constant so the size never gets hardcoded again.
const MAX_MB = Math.round(MAX_CONTENT_BYTES / (1024 * 1024));

// Idempotent registration guard: MarkEdit loads the extension script once per webview context, so the
// same script can run multiple times (confirmed in a two-stage pre-flight test). A global sentinel blocks duplicate menu registration.
const g = globalThis as unknown as { __stickyCastRegistered?: boolean };
if (!g.__stickyCastRegistered) {
  g.__stickyCastRegistered = true;

  MarkEdit.addMainMenuItem([{
    title: "Pop as Sticky",
    action: () => {
      const m = t(detectLang(), MAX_MB);
      // Use the selection if there is one, otherwise the whole document. deriveContent does the work (pure function, covered by tests).
      const selections = MarkEdit.editorAPI.getSelections();
      const hasSelection = selections.some((r) => r.to !== r.from);
      const content = deriveContent(selections, (range) => MarkEdit.editorAPI.getText(range));

      // Treat a whitespace-only document or selection as empty too (avoids launching an invisible blank card). The launched content keeps the original text.
      if (content.trim().length === 0) {
        void MarkEdit.showAlert({ title: m.emptyTitle, message: m.emptyBody });
        return;
      }

      // Over the content limit (raw bytes): reject and warn instead of truncating (no silent failure, no truncation).
      const url = buildStickyURL(content, MAX_CONTENT_BYTES);
      if (url === null) {
        void MarkEdit.showAlert({
          title: hasSelection ? m.tooLargeTitleSel : m.tooLargeTitleDoc,
          message: m.tooLargeBody,
        });
        return;
      }
      window.location.href = url;
    },
  }]);
}
