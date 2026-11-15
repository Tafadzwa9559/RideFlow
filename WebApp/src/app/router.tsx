/* oxlint-disable react/only-export-components -- Router owns lazy route declarations. */
import { lazy } from "react";
import { createBrowserRouter, Link, Navigate } from "react-router-dom";
const Guard = lazy(() => import("../components/common/ProtectedRoute"));
import PublicLayout from "../components/layout/PublicLayout";
const Landing = lazy(() => import("../pages/Home/HomePage"));
const PublicPages = lazy(() => import("../features/shared/PublicPages"));
const Login = lazy(() => import("../pages/Auth/LoginPage"));
const AppLayout = lazy(() =>
  import("../components/layout/AppLayout").then((m) => ({
    default: m.AppLayout,
  })),
);
const Admin = lazy(() => import("../pages/Dashboard/AdminDashboard"));
function NotFound() {
  return (
    <section className="site-container site-not-found">
      <span className="site-eyebrow">404 · A DIFFERENT DIRECTION</span>
      <h1>Let’s get you back on track.</h1>
      <p>
        This page doesn’t exist. Discover Trivia or find the mobile app’s
        release information.
      </p>
      <div className="site-actions">
        <Link className="site-button" to="/">
          Return home
        </Link>
        <Link className="site-text-link" to="/download">
          Find the app →
        </Link>
      </div>
    </section>
  );
}
export const router = createBrowserRouter([
  {
    element: <PublicLayout />,
    children: [
      { path: "/", element: <Landing /> },
      ...[
        "how-it-works",
        "ride",
        "drive",
        "safety",
        "about",
        "contact",
        "download",
        "faq",
      ].map((path) => ({
        path: `/${path}`,
        element: <PublicPages pathname={`/${path}`} />,
      })),
      { path: "*", element: <NotFound /> },
    ],
  },
  { path: "/admin/login", element: <Login /> },
  {
    element: <Guard role="admin" />,
    children: [
      {
        path: "/admin",
        element: <AppLayout role="admin" />,
        children: [
          { index: true, element: <Navigate to="dashboard" replace /> },
          ...[
            "dashboard",
            "passengers",
            "drivers",
            "verification",
            "vehicles",
            "rides",
            "payments",
            "disputes",
            "analytics",
            "notifications",
            "settings",
            "fares",
          ].map((page) => ({ path: page, element: <Admin page={page} /> })),
        ],
      },
    ],
  },
]);
