import { useRef, type ReactNode } from "react";
import { motion, useReducedMotion, useIsPresent } from "motion/react";
import type { Location, NavigationType } from "react-router-dom";
export default function PageTransition({
  children,
  location,
  action,
}: {
  children: ReactNode;
  location: Location;
  action: NavigationType;
}) {
  const present = useIsPresent();
  const reduced = useReducedMotion();
  const region = useRef<HTMLDivElement>(null);
  return (
    <motion.div
      ref={region}
      className="public-page"
      data-page={location.pathname}
      inert={!present}
      initial={{ opacity: reduced ? 1 : 0, y: reduced ? 0 : 10 }}
      animate={{
        opacity: 1,
        y: 0,
        transition: { duration: reduced ? 0 : 0.44, ease: [0.22, 1, 0.36, 1] },
      }}
      exit={{
        opacity: reduced ? 1 : 0,
        y: reduced ? 0 : -6,
        transition: { duration: reduced ? 0 : 0.22, ease: [0.4, 0, 1, 1] },
      }}
      onAnimationComplete={() => {
        if (
          !present ||
          region.current?.contains(document.activeElement) ||
          document.querySelector('.site-header [aria-expanded="true"]')
        )
          return;
        if (!location.hash && action !== "POP") {
          const heading = region.current?.querySelector<HTMLElement>("h1");
          heading?.setAttribute("tabindex", "-1");
          heading?.focus({ preventScroll: true });
        }
      }}
    >
      {children}
    </motion.div>
  );
}
