import { Plugin, Notice } from "obsidian";

export default class StickyCastSpikePlugin extends Plugin {
  onload() {
    this.addCommand({
      id: "spike-ping",
      name: "(spike) ping",
      callback: () => new Notice("StickyCast spike plugin loaded."),
    });
  }
}
