import { NavLink, useNavigate } from "react-router-dom";
import {
  Bell,
  CarFront,
  ChartNoAxesCombined,
  CreditCard,
  FileCheck,
  House,
  LogOut,
  Route,
  Settings,
  ShieldCheck,
  Users,
  X,
} from "lucide-react";
import { useAuth } from "../../hooks/useAuth";
import { toast } from "sonner";
import { Logo, Button } from "../ui/primitives";
import type { Role } from "../../types/user";
const menus = [
  ["dashboard", "Overview", House],
  ["passengers", "Passengers", Users],
  ["drivers", "Drivers", CarFront],
  ["verification", "Driver verification", FileCheck],
  ["vehicles", "Vehicles", CarFront],
  ["rides", "Ride management", Route],
  ["payments", "Payments", CreditCard],
  ["disputes", "Disputes", ShieldCheck],
  ["analytics", "Analytics", ChartNoAxesCombined],
  ["notifications", "Notifications", Bell],
  ["settings", "Settings", Settings],
] as const;
export default function Sidebar({
  open,
  onClose,
}: {
  role: Role;
  open: boolean;
  onClose: () => void;
}) {
  const { user, logout, demo } = useAuth();
  const navigate = useNavigate();
  return (
    <aside className={`sidebar ${open ? "open" : ""}`}>
      <div className="row between">
        <Logo />
        <Button
          className="secondary icon-btn mobile-only"
          aria-label="Close navigation"
          onClick={onClose}
        >
          <X size={18} />
        </Button>
      </div>
      <div className="workspace-label">
        Administration {demo && <span>DEMO</span>}
      </div>
      <nav aria-label="Admin navigation">
        {menus.map(([path, label, Icon]) => (
          <NavLink key={path} to={`/admin/${path}`} onClick={onClose}>
            <Icon size={18} />
            {label}
          </NavLink>
        ))}
      </nav>
      <div className="sidebar-bottom">
        <button
          className="profile"
          onClick={async () => {
            try {
              await logout();
            } catch {
              toast.error(
                "Local session cleared. The backend could not confirm session revocation.",
              );
            } finally {
              navigate("/admin/login");
            }
          }}
        >
          <span className="avatar">{user?.firstName?.[0] || "A"}</span>
          <span>
            <strong>
              {user?.firstName} {user?.lastName}
            </strong>
            <small>Sign out</small>
          </span>
          <LogOut size={17} />
        </button>
      </div>
    </aside>
  );
}
