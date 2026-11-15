import { useEffect, useRef } from "react";
import { Link, NavLink } from "react-router-dom";
import { X, ArrowUpRight } from "lucide-react";
import {
  primaryNavigation,
  secondaryNavigation,
  desktopNavigationQuery,
} from "../../config/navigation";
import { motion, useReducedMotion } from "motion/react";
export default function MobileNavigation({
  onClose,
  returnFocus,
}: {
  onClose: () => void;
  returnFocus: () => void;
}) {
  const panel = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  useEffect(() => {
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const background = Array.from(
      document.querySelectorAll<HTMLElement>(
        "#main-content,.site-footer,.site-nav",
      ),
    );
    const previousInert = background.map((node) => node.inert);
    background.forEach((node) => {
      node.inert = true;
    });
    panel.current?.querySelector<HTMLElement>("button, a")?.focus();
    const keydown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        onClose();
      }
      if (e.key === "Tab") {
        const nodes = panel.current?.querySelectorAll<HTMLElement>("a,button");
        if (!nodes?.length) return;
        if (e.shiftKey && document.activeElement === nodes[0]) {
          e.preventDefault();
          nodes[nodes.length - 1].focus();
        } else if (
          !e.shiftKey &&
          document.activeElement === nodes[nodes.length - 1]
        ) {
          e.preventDefault();
          nodes[0].focus();
        }
      }
    };
    document.addEventListener("keydown", keydown);
    const breakpoint = matchMedia(desktopNavigationQuery);
    const resized = () => {
      if (breakpoint.matches) onClose();
    };
    breakpoint.addEventListener("change", resized);
    return () => {
      document.body.style.overflow = overflow;
      background.forEach((node, index) => {
        node.inert = previousInert[index];
      });
      document.removeEventListener("keydown", keydown);
      breakpoint.removeEventListener("change", resized);
      returnFocus();
    };
  }, [onClose, returnFocus]);
  return (
    <motion.div
      className="mobile-menu-layer"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: reduced ? 0 : 0.32 }}
    >
      <div
        className="mobile-menu-backdrop"
        onClick={onClose}
        aria-hidden="true"
      />
      <motion.div
        ref={panel}
        id="mobile-navigation"
        role="dialog"
        aria-modal="true"
        aria-label="Mobile navigation"
        className="mobile-menu-panel"
        initial={{ y: reduced ? 0 : -12, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        exit={{ y: reduced ? 0 : -8, opacity: 0 }}
        transition={{ duration: reduced ? 0 : 0.34, ease: [0.22, 1, 0.36, 1] }}
      >
        <div className="mobile-menu-title">
          <span>EXPLORE TRIVIA</span>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close navigation menu"
          >
            <X size={21} aria-hidden="true" />
          </button>
        </div>
        <nav aria-label="Main navigation">
          {primaryNavigation.map(([to, label], index) => (
            <motion.div
              key={to}
              initial={{ opacity: 0, y: reduced ? 0 : 7 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                duration: reduced ? 0 : 0.22,
                delay: reduced ? 0 : index * 0.018,
              }}
            >
              <NavLink end to={to} onClick={onClose}>
                {label}
                <span className="mobile-link-index" aria-hidden="true">
                  0{index + 1}
                </span>
              </NavLink>
            </motion.div>
          ))}
          <div className="mobile-secondary-links">
            {secondaryNavigation.map(([to, label]) => (
              <Link key={to} to={to} onClick={onClose}>
                {label}
                <ArrowUpRight size={13} aria-hidden="true" />
              </Link>
            ))}
          </div>
        </nav>
        <Link className="site-button" to="/download" onClick={onClose}>
          Download App <ArrowUpRight size={17} aria-hidden="true" />
        </Link>
        <p>Your Journey. Your Choice.</p>
      </motion.div>
    </motion.div>
  );
}
