import { Plugin, Notice, MarkdownView, type Editor } from "obsidian";
import { buildStickyURL } from "./encoding";
import { MAX_CONTENT_BYTES } from "./limits";
import { deriveContent } from "./derive";

const MAX_MB = Math.round(MAX_CONTENT_BYTES / (1024 * 1024));

// We launch the sticky:// URL through Electron's shell rather than window.location: Obsidian
// intercepts in-page scheme navigations, and there is no first-party API to fire a custom
// external scheme. Guarded so a renderer without node integration degrades to a Notice.
function electronShell(): { openExternal(url: string): Promise<void> } | null {
  try {
    return (window as any).require?.("electron")?.shell ?? null;
  } catch {
    return null;
  }
}

export default class StickyCastPlugin extends Plugin {
  onload() {
    // Launch API reachability: warns only when the shell is missing, so a healthy install is silent.
    if (!electronShell()) {
      console.warn("[stickycast] electron.shell unavailable — Pop as Sticky will not launch here.");
    }

    // Plain callback (not editorCallback) so the command still works when focus is on the
    // ribbon, command palette, or another pane — popActive() resolves the target editor itself.
    this.addCommand({
      id: "pop-as-sticky",
      name: "Pop as Sticky",
      callback: () => this.popActive(),
    });

    this.addRibbonIcon("sticky-note", "Pop as Sticky", () => this.popActive());

    this.registerEvent(
      this.app.workspace.on("editor-menu", (menu, editor) => {
        menu.addItem((item) =>
          item.setTitle("Pop as Sticky").setIcon("sticky-note").onClick(() => this.pop(editor)),
        );
      }),
    );
  }

  // Resolve the note to pop for the command/ribbon (which aren't handed an editor).
  // Falls back progressively so clicking the ribbon (which moves focus off the note) still works.
  private resolveEditor(): Editor | null {
    const w = this.app.workspace;
    const focused = w.activeEditor?.editor;
    if (focused) return focused;
    const activeView = w.getActiveViewOfType(MarkdownView);
    if (activeView?.editor) return activeView.editor;
    // With several markdown panes and focus off all of them, this picks the most recently
    // active one (Obsidian's own "active pane" notion) — the intuitive target.
    const recent = w.getMostRecentLeaf();
    if (recent?.view instanceof MarkdownView && recent.view.editor) return recent.view.editor;
    return null;
  }

  private popActive() {
    const editor = this.resolveEditor();
    if (!editor) {
      new Notice("Open a Markdown note to pop as a sticky.");
      return;
    }
    this.pop(editor);
  }

  private pop(editor: Editor) {
    if (process.platform !== "darwin") {
      new Notice("StickyCast is macOS-only.");
      return;
    }
    const content = deriveContent(
      editor.listSelections(),
      (from, to) => editor.getRange(from, to),
      () => editor.getValue(),
    );
    if (content.trim().length === 0) {
      new Notice("Nothing to pop — the document or selection is empty.");
      return;
    }
    const url = buildStickyURL(content, MAX_CONTENT_BYTES);
    if (url === null) {
      new Notice(`A sticky can hold about ${MAX_MB}MB. Select a smaller part and try again.`);
      return;
    }
    const shell = electronShell();
    if (!shell) {
      new Notice("Cannot launch: electron.shell is unavailable.");
      return;
    }
    void shell.openExternal(url).catch((e) => {
      console.error("[stickycast] openExternal failed", e);
      new Notice("Failed to launch the sticky — see console.");
    });
  }
}
