import { Plugin, Notice, Modal, App, getIconIds } from "obsidian";
import { buildStickyURL } from "../../extension/src/encoding";
import { MAX_CONTENT_BYTES } from "../../extension/src/limits";
import { makeContent, sha256Hex } from "./spike";

function requireElectronShell(): { openExternal(url: string): Promise<void> } | null {
  try {
    return (window as any).require?.("electron")?.shell ?? null;
  } catch {
    return null;
  }
}

class ByteCountModal extends Modal {
  constructor(app: App, private onSubmit: (n: number) => void) { super(app); }
  onOpen() {
    this.titleEl.setText("Spike: byte count to fire");
    const input = this.contentEl.createEl("input", { type: "number" });
    input.value = "1048576"; // set explicitly — DomElementInfo may not pre-fill number inputs
    const btn = this.contentEl.createEl("button", { text: "Fire" });
    const submit = () => {
      const n = Number(input.value); // Number, not parseInt: "1e6" → 1000000, "3.7" → rejected below
      this.close();
      if (Number.isInteger(n) && n > 0) this.onSubmit(n);
    };
    btn.onclick = submit;
    input.addEventListener("keydown", (e) => { if (e.key === "Enter") submit(); });
  }
  onClose() { this.contentEl.empty(); }
}

export default class StickyCastSpikePlugin extends Plugin {
  onload() {
    this.addCommand({
      id: "spike-probe",
      name: "(spike) probe environment",
      callback: () => {
        const shell = requireElectronShell();
        const hasIcon = getIconIds().includes("sticky-note");
        const msg = `electron.shell: ${shell ? "OK" : "MISSING"} | sticky-note icon: ${hasIcon ? "OK" : "MISSING"}`;
        console.log("[stickycast-spike]", msg);
        new Notice(msg);
      },
    });

    this.addCommand({
      id: "spike-fire",
      name: "(spike) fire N bytes",
      callback: () => new ByteCountModal(this.app, (n) => void this.fire(n)).open(),
    });
  }

  private async fire(bytes: number) {
    // Everything is inside try so a throw (OOM building the string, crypto missing)
    // surfaces instead of being swallowed by the `void this.fire(n)` call site.
    try {
      const content = makeContent(bytes);
      const hash = sha256Hex(content);
      const url = buildStickyURL(content, MAX_CONTENT_BYTES);
      if (url === null) {
        const msg = `over content cap (${MAX_CONTENT_BYTES} bytes) — not fired`;
        console.log("[stickycast-spike]", msg);
        new Notice(msg);
        return;
      }
      console.log("[stickycast-spike] FIRE", { bytes, urlChars: url.length, sha256: hash });
      const shell = requireElectronShell();
      if (!shell) { new Notice("electron.shell unavailable — cannot fire"); return; }
      // A resolved openExternal does NOT prove macOS delivered the full URL — whether it
      // truncates silently vs rejects is exactly what Gate 1 measures. A reject lands in
      // catch; the only valid PASS is a materialized sticker whose exported sha256 equals
      // the logged hash, not this Notice.
      await shell.openExternal(url);
      new Notice(`fired ${bytes} bytes (sha256 ${hash.slice(0, 12)}…) — verify via export, not this notice`);
    } catch (e) {
      console.error("[stickycast-spike] fire() threw/rejected", e);
      new Notice("fire failed — see console");
    }
  }
}
