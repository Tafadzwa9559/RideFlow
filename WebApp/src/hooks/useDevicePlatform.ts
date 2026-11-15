import { useState } from "react";
export type Platform = "android" | "ios" | "desktop";
export function detectPlatform(
  agent: string,
  platform = "",
  touchPoints = 0,
): Platform {
  if (/android/i.test(agent)) return "android";
  if (
    /iPhone|iPad|iPod/i.test(agent) ||
    (/Mac/i.test(platform) && touchPoints > 1)
  )
    return "ios";
  return "desktop";
}
export function useDevicePlatform() {
  const [detected] = useState<Platform>(() =>
    typeof navigator === "undefined"
      ? "desktop"
      : detectPlatform(
          navigator.userAgent,
          navigator.platform,
          navigator.maxTouchPoints,
        ),
  );
  const [selected, setSelected] = useState<Platform>(detected);
  return { detected, selected, setSelected };
}
