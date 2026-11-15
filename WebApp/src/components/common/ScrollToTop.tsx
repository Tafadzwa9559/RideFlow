import { useLayoutEffect } from "react";
import { useReducedMotion } from "motion/react";
import type { Location, NavigationType } from "react-router-dom";
import { scrollPositions } from "../../utils/scrollPositions";
export default function ScrollToTop({
  location,
  action,
}: {
  location: Location;
  action: NavigationType;
}) {
  const reduced = useReducedMotion();
  useLayoutEffect(() => {
    if (action === "POP" && scrollPositions.has(location.key)) {
      window.scrollTo({
        top: scrollPositions.get(location.key)!,
        behavior: "instant",
      });
    } else if (location.hash) {
      let id = location.hash.slice(1);
      try {
        id = decodeURIComponent(id);
      } catch {
        /* Keep literal malformed hashes. */
      }
      document
        .getElementById(id)
        ?.scrollIntoView({
          behavior: reduced ? "instant" : "smooth",
          block: "start",
        });
    } else {
      // Reset beneath the outgoing fade, before the new page paints.
      window.scrollTo({ top: 0, behavior: "instant" });
    }
  }, [location.key, location.hash, action, reduced]);
  return null;
}
