import { useEffect } from "react";
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../hooks/useAuth";
import LoadingSpinner from "./LoadingSpinner";
import type { Role } from "../../types/user";
export default function ProtectedRoute({ role = "admin" }: { role?: Role }) {
  const { user, initialized, initialize } = useAuth();
  const { pathname } = useLocation();
  useEffect(() => {
    void initialize();
  }, [initialize]);
  if (!initialized) return <LoadingSpinner />;
  if (!user || user.role !== "admin" || user.role !== role)
    return <Navigate to="/admin/login" state={{ from: pathname }} replace />;
  return <Outlet />;
}
