import { useEffect, useId, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { ChevronDown } from "lucide-react";
export default function DropdownMenu({
  label,
  items,
}: {
  label: string;
  items: readonly (readonly [string, string])[];
}) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const id = useId();
  const reduced = useReducedMotion();
  useEffect(() => {
    if (!open) return;
    const close = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", close);
    return () => document.removeEventListener("pointerdown", close);
  }, [open]);
  return (
    <div
      ref={root}
      className="site-dropdown"
      onBlur={(e) => {
        if (!e.currentTarget.contains(e.relatedTarget)) setOpen(false);
      }}
      onKeyDown={(e) => {
        if (e.key === "Escape") {
          e.stopPropagation();
          setOpen(false);
          trigger.current?.focus();
        }
        if (["ArrowDown", "ArrowUp", "Home", "End"].includes(e.key)) {
          e.preventDefault();
          const links = Array.from(
            root.current?.querySelectorAll<HTMLAnchorElement>(
              ".dropdown-panel a",
            ) || [],
          );
          if (!open) {
            setOpen(true);
            requestAnimationFrame(() =>
              root.current
                ?.querySelector<HTMLAnchorElement>(
                  e.key === "ArrowUp"
                    ? ".dropdown-panel a:last-child"
                    : ".dropdown-panel a",
                )
                ?.focus(),
            );
            return;
          }
          const index = links.indexOf(
            document.activeElement as HTMLAnchorElement,
          );
          const next =
            e.key === "Home"
              ? 0
              : e.key === "End"
                ? links.length - 1
                : (index + (e.key === "ArrowUp" ? -1 : 1) + links.length) %
                  links.length;
          links[next]?.focus();
        }
      }}
    >
      <button
        ref={trigger}
        type="button"
        className="dropdown-trigger"
        aria-expanded={open}
        aria-controls={id}
        onClick={() => setOpen(!open)}
      >
        {label}
        <ChevronDown size={13} className={open ? "turned" : ""} />
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            id={id}
            className="dropdown-panel"
            initial={{ opacity: 0, y: reduced ? 0 : 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: reduced ? 0 : 4 }}
            transition={{ duration: reduced ? 0 : 0.18 }}
          >
            {items.map(([to, text]) => (
              <Link key={to} to={to} onClick={() => setOpen(false)}>
                {text}
                <span aria-hidden="true">↗</span>
              </Link>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
