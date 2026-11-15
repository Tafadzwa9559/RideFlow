import { useRef, useState, type CSSProperties, type ReactNode } from "react";
import { motion, useInView, useReducedMotion } from "motion/react";

export type RevealDirection = "left" | "right" | "up" | "down" | "none";
type RevealTag =
  | "section"
  | "div"
  | "article"
  | "li"
  | "header"
  | "figure"
  | "span"
  | "h1"
  | "p";
export interface ScrollRevealProps {
  children: ReactNode;
  className?: string;
  id?: string;
  "aria-label"?: string;
  direction?: RevealDirection;
  delay?: number;
  duration?: number;
  distance?: number;
  once?: boolean;
  as?: RevealTag;
}
const defaults = {
  left: [60, 0.65],
  right: [70, 0.75],
  up: [45, 0.6],
  down: [35, 0.55],
  none: [0, 0.4],
} as const;
const visible = { opacity: 1, x: 0, y: 0 };
/** One viewport entrance primitive; the semantic tag preserves existing layouts. */
export default function ScrollReveal({
  children,
  className = "",
  id,
  direction = "up",
  delay = 0,
  duration = defaults[direction][1],
  distance = defaults[direction][0],
  once = true,
  as = "section",
  "aria-label": ariaLabel,
}: ScrollRevealProps) {
  const reduced = useReducedMotion();
  const [focused, setFocused] = useState(false);
  const Element = motion[as];
  const target = useRef<HTMLElement | null>(null);
  const inView = useInView(target, { once, amount: 0.15 });
  const horizontal = direction === "left" || direction === "right";
  const offset =
    direction === "left" || direction === "down" ? -distance : distance;
  const style = {
    "--reveal-desktop": `${offset}px`,
    "--reveal-mobile": `${Math.sign(offset) * Math.min(Math.abs(offset), 24)}px`,
  } as CSSProperties;
  return (
    <Element
      className={`scroll-reveal ${className}`}
      id={id}
      aria-label={ariaLabel}
      style={style}
      data-reveal={direction}
      ref={(element: HTMLElement | null) => {
        target.current = element;
      }}
      initial={false}
      animate={
        reduced || focused || inView
          ? visible
          : {
              opacity: 0,
              x: horizontal ? "var(--reveal-distance)" : 0,
              y:
                horizontal || direction === "none"
                  ? 0
                  : "var(--reveal-distance)",
            }
      }
      transition={{
        duration: reduced || focused ? 0 : duration,
        delay: reduced || focused ? 0 : Math.min(Math.max(delay, 0), 0.3),
        ease: [0.22, 1, 0.36, 1],
      }}
      onFocusCapture={() => setFocused(true)}
    >
      {children}
    </Element>
  );
}
