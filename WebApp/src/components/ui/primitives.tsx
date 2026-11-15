import {
  useEffect,
  useRef,
  type ButtonHTMLAttributes,
  type ReactNode,
} from "react";
import { motion, useReducedMotion } from "motion/react";
import { ArrowUpRight, Route, X } from "lucide-react";
import { Link } from "react-router-dom";
import { projectConfig } from "../../config/project";
export function Logo() {
  return (
    <Link to="/" className="logo" aria-label="Trivia home">
      <span>
        <Route size={23} />
      </span>
      trivia<span className="logo-dot">.</span>
    </Link>
  );
}
export function Button({
  children,
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button className={`btn ${className}`} {...props}>
      {children}
    </button>
  );
}
export function Empty({
  title,
  children,
}: {
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="empty">
      <Route size={30} />
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}
export function Badge({ children }: { children: ReactNode }) {
  return <span className="badge">{children}</span>;
}
export function PageHeading({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="page-heading">
      <div>
        <p className="eyebrow">
          {eyebrow || projectConfig.tagline.toUpperCase()}
        </p>
        <h1>{title}</h1>
        {description && <p className="muted">{description}</p>}
      </div>
      {action}
    </div>
  );
}
export function Modal({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLElement>(null);
  const close = useRef(onClose);
  useEffect(() => {
    close.current = onClose;
  }, [onClose]);
  const reduced = useReducedMotion();
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const background: { node: HTMLElement; inert: boolean }[] = [];
    let branch = dialog.current?.parentElement;
    while (branch && branch !== document.body) {
      for (const sibling of Array.from(branch.parentElement?.children || [])) {
        if (sibling !== branch && sibling instanceof HTMLElement) {
          background.push({ node: sibling, inert: sibling.inert });
          sibling.inert = true;
        }
      }
      branch = branch.parentElement;
    }
    dialog.current?.querySelector<HTMLButtonElement>('button')?.focus();
    const keydown = (event: KeyboardEvent) => {
      if (event.key === "Escape") close.current();
      if (event.key !== "Tab") return;
      const elements = dialog.current?.querySelectorAll<HTMLElement>(
        "a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled])",
      );
      if (!elements?.length) return;
      const first = elements[0];
      const last = elements[elements.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      }
      if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", keydown);
    return () => {
      document.body.style.overflow = originalOverflow;
      document.removeEventListener("keydown", keydown);
      background.forEach(({ node, inert }) => { node.inert = inert; });
      if (previous?.isConnected) previous.focus({ preventScroll: true });
    };
  }, []);
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <motion.section
        ref={dialog}
        initial={{ opacity: reduced ? 1 : 0, y: reduced ? 0 : 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.15 }}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="modal"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="row between">
          <h2>{title}</h2>
          <Button
            className="icon-btn secondary"
            aria-label="Close dialog"
            onClick={onClose}
            autoFocus
          >
            <X size={18} />
          </Button>
        </div>
        {children}
      </motion.section>
    </div>
  );
}
export function ArrowLink({
  to,
  children,
}: {
  to: string;
  children: ReactNode;
}) {
  return (
    <Link className="text-link" to={to}>
      {children}
      <ArrowUpRight size={17} />
    </Link>
  );
}
