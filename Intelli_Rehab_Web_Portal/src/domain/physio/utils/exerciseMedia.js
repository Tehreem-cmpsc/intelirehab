// Where an exercise's illustration/video lives. exercises.media_url is either a
// path relative to the apps ("exercises/elbow-flexion-and-extension.webp",
// served from the portal's /exercises/ folder) or a full https:// URL (a real
// recorded video, say). Anything else (javascript:, data:, protocol-relative)
// is refused, since this value comes from a table physios can edit.
export function resolveMediaUrl(mediaUrl, base = "/") {
  if (typeof mediaUrl !== "string") return null;
  const url = mediaUrl.trim();
  if (!url) return null;
  if (/^https:\/\//i.test(url)) return url;
  if (/^[a-z][a-z0-9+.-]*:/i.test(url) || url.startsWith("//") || url.includes("..")) return null;
  const root = base.endsWith("/") ? base : base + "/";
  return root + url.replace(/^\/+/, "");
}
