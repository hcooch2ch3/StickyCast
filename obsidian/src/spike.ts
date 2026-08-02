import { createHash } from "crypto";

// Exactly `n` ASCII bytes (1 char == 1 byte), self-labeled with the size so the
// sticker and its export filename identify their probe. Any truncation changes the sha256.
export function makeContent(n: number): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const label = `[n=${n}]`;
  let out = label.length <= n ? label : label.slice(0, n);
  for (let i = out.length; i < n; i++) out += alphabet[i % alphabet.length];
  return out;
}

export function sha256Hex(s: string): string {
  return createHash("sha256").update(s, "utf8").digest("hex");
}
