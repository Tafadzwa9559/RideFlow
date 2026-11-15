import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "sonner";
import { useAuth } from "../../hooks/useAuth";
import { useEffect, useState } from "react";
import { Outlet, Link, useLocation } from "react-router-dom";
import { Bell, ChevronRight, MapPin, Menu } from "lucide-react";
import Sidebar from "./Sidebar";
import type { Role } from "../../types/domain";
import { useAppStore } from "../../store/useAppStore";
import { Button } from "../ui/primitives";
import { projectConfig } from "../../config/project";
import { currentYear } from "../../utils/localisation";
const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 30000 } } });
export function AppLayout({ role }: { role: Role }) {
  const { demo } = useAuth();
  const { pathname } = useLocation();
  useEffect(() => {
    document.title = `${projectConfig.productName} Administration | ${pathname.split("/").at(-1) || "Dashboard"}`;
    document
      .querySelector('meta[name="robots"]')
      ?.setAttribute("content", "noindex, nofollow");
  }, [pathname]);
  const [open, setOpen] = useState(false);
  const user = useAppStore((s) => s.user);
  const unread = useAppStore((s) => s.notices.filter((n) => !n.read).length);
  return (
    <QueryClientProvider client={queryClient}>
    <div className="app-shell">
      <Sidebar role={role} open={open} onClose={() => setOpen(false)} />
      {open && (
        <button
          aria-label="Close navigation"
          className="sidebar-overlay"
          onClick={() => setOpen(false)}
        />
      )}
      <div className="workspace">
        <header className="app-header">
          <div className="row">
            <Button
              className="secondary icon-btn mobile-only"
              aria-label="Open navigation"
              onClick={() => setOpen(true)}
            >
              <Menu size={20} />
            </Button>
            <span className="breadcrumb">
              Workspace <ChevronRight size={14} />{" "}
              <strong>
                {role === "passenger"
                  ? "Passenger"
                  : role === "driver"
                    ? "Driver"
                    : "Operations"}
              </strong>
            </span>
          </div>
          <div className="row">
            <span className="location-pill">
              <MapPin size={14} /> {projectConfig.country} ·{" "}
              {projectConfig.defaultCurrency}
            </span>
            <Link
              className="notification-button"
              to={`/${role}/notifications`}
              aria-label={`${unread} unread notifications`}
            >
              <Bell size={20} />
              {unread > 0 && <i />}
            </Link>
            <span className="avatar small">{user?.firstName[0]}</span>
          </div>
        </header>
        <div className="demo-banner">
          <span className="status-dot" />{" "}
          {demo ? "Development demo workspace" : "Authenticated administration"}{" "}
          <span className="demo-detail">
            {demo
              ? "· Sample data. No real rides, payments or verification."
              : "· Live management data adapter not enabled."}
          </span>
          <span className="connection">Live connection off</span>
        </div>
        <main className="app-main">
          {demo ? (
            <Outlet />
          ) : (
            <section className="panel">
              <h1>Administration data is not connected.</h1>
              <p>
                Your backend-authenticated session is active. This management
                module needs its Django data adapter before live records or
                changes are available.
              </p>
              <p>
                Sample controls are available only in the explicitly enabled
                development demo.
              </p>
            </section>
          )}
        </main>
        <footer className="app-footer">
          © {currentYear()} · {projectConfig.productName} —{" "}
          {projectConfig.tagline}
          <span>Developed by {projectConfig.developer}</span>
        </footer>
      </div>
    </div>
    <Toaster richColors position="top-right" />
    </QueryClientProvider>
  );
}
