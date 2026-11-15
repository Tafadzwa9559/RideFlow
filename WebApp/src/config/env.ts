export function safeUrl(value: string | undefined, protocols = ["https:"]) {
  if (!value?.trim()) return "";
  try {
    const url = new URL(value);
    return protocols.includes(url.protocol) && !url.username && !url.password
      ? url.href
      : "";
  } catch {
    return "";
  }
}
function storeUrl(value: string | undefined, host: string) {
  const url = safeUrl(value);
  if (!url) return "";
  const parsed = new URL(url);
  if (parsed.hostname !== host) return "";
  const listing =
    host === "play.google.com"
      ? parsed.pathname === "/store/apps/details" &&
        !!parsed.searchParams.get("id")
      : /\/app\/(?:[^/]+\/)?id\d+\/?$/.test(parsed.pathname);
  return listing ? url : "";
}
export const env = Object.freeze({
  apiBaseUrl: safeUrl(import.meta.env.VITE_API_BASE_URL, [
    "http:",
    "https:",
  ]).replace(/\/$/, ""),
  wsBaseUrl: safeUrl(import.meta.env.VITE_WS_BASE_URL, ["ws:", "wss:"]).replace(
    /\/$/,
    "",
  ),
  androidUrl: storeUrl(import.meta.env.VITE_ANDROID_APP_URL, "play.google.com"),
  iosUrl: storeUrl(import.meta.env.VITE_IOS_APP_URL, "apps.apple.com"),
  apkUrl:
    import.meta.env.VITE_OFFICIAL_APK_VERIFIED === "true"
      ? safeUrl(import.meta.env.VITE_OFFICIAL_APK_URL)
      : "",
  supportEmail: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
    import.meta.env.VITE_SUPPORT_EMAIL || "",
  )
    ? import.meta.env.VITE_SUPPORT_EMAIL
    : "",
  contactUrl: safeUrl(import.meta.env.VITE_CONTACT_API_URL),
  socialUrl: safeUrl(import.meta.env.VITE_SOCIAL_URL),
  siteUrl: safeUrl(import.meta.env.VITE_SITE_URL),
  adminDemo:
    import.meta.env.DEV && import.meta.env.VITE_ENABLE_ADMIN_DEMO === "true",
});
