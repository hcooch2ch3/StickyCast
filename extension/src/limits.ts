// extension/src/limits.ts: sticky content limit (in raw bytes). Single source.
//
// The three budgets are separate (iter review):
//   - Transport (URL): measured lossless up to 32MB (drops at 64MB). Not the bottleneck.
//   - Storage (UserDefaults) / render (swift-markdown-ui): poor with large blobs, so this is the real bottleneck.
// So the product limit is set to what storage and rendering can handle, not what transport allows.
//
// 1MB: 17x this project's largest document (≈59KB), about one book chapter. Covers every real-world markdown
// document while keeping UserDefaults (up to 30 cards x 1MB) and rendering healthy. Over the limit, the extension refuses to launch and warns.
export const MAX_CONTENT_BYTES = 1 * 1024 * 1024;
