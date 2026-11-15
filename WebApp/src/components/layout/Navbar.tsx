import { useCallback, useEffect, useRef, useState } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { ArrowUpRight, Menu, X } from "lucide-react";
import {
  primaryNavigation,
  secondaryNavigation,
} from "../../config/navigation";
import "./Navbar.css";
import DropdownMenu from "../ui/DropdownMenu";
import MobileNavigation from "./MobileNavigation";
export default function Navbar() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const trigger = useRef<HTMLButtonElement>(null);
  const location = useLocation();
  const navigation = useRef<HTMLElement>(null);
  const reduced = useReducedMotion();
  const close = useCallback(() => setOpen(false), []);
  const returnFocus = useCallback(() => {
    const target = trigger.current?.getClientRects().length
      ? trigger.current
      : navigation.current?.querySelector<HTMLAnchorElement>(
          'a[aria-current="page"]',
        );
    target?.focus({ preventScroll: true });
  }, []);
  useEffect(() => {
    let frame = 0;
    const update = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => setScrolled(window.scrollY > 48));
    };
    update();
    window.addEventListener("scroll", update, { passive: true });
    return () => {
      window.removeEventListener("scroll", update);
      cancelAnimationFrame(frame);
    };
  }, []);
  return (
    <header className={`site-header ${scrolled ? "is-scrolled" : ""}`}>
      <motion.div
        className="site-nav"
        initial={reduced ? false : { opacity: 0, y: -20, scale: 0.98 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: reduced ? 0 : 0.58, ease: [0.22, 1, 0.36, 1] }}
      >
        <Link className="nav-wordmark" to="/" aria-label="Trivia home">
          trivia<span aria-hidden="true">.</span>
        </Link>
        <nav
          ref={navigation}
          className="desktop-navigation"
          aria-label="Main navigation"
          key={location.pathname}
        >
          {primaryNavigation.map(([to, label]) => (
            <NavLink end to={to} key={to}>
              {label}
            </NavLink>
          ))}
          <DropdownMenu label="More" items={secondaryNavigation} />
        </nav>
        <Link className="site-button nav-download" to="/download" aria-label="Download App">
          <span className="nav-download-label">Download App</span>
          <span className="nav-download-compact" aria-hidden="true">Get App</span>
          <ArrowUpRight size={16} aria-hidden="true" />
        </Link>
        <button
          ref={trigger}
          type="button"
          className="menu-toggle"
          aria-label={open ? "Close menu" : "Open menu"}
          aria-expanded={open}
          aria-controls="mobile-navigation"
          onClick={() => setOpen(!open)}
        >
          {open ? <X aria-hidden="true" /> : <Menu aria-hidden="true" />}
        </button>
      </motion.div>
      <AnimatePresence>
        {open && <MobileNavigation onClose={close} returnFocus={returnFocus} />}
      </AnimatePresence>
    </header>
  );
}
