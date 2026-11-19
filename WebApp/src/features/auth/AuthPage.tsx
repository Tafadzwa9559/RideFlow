import { useEffect, useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Eye, EyeOff } from "lucide-react";
import { Logo } from "../../components/ui/primitives";
import { useAuth } from "../../hooks/useAuth";
import { env } from "../../config/env";
import "../shared/marketing.css";
import { projectConfig } from "../../config/project";
const schema = z.object({
  email: z.email("Enter a valid email address."),
  password: z.string().min(1, "Enter your password."),
});
type Fields = z.infer<typeof schema>;
export default function AuthPage() {
  const auth = useAuth();
  const initialize = auth.initialize;
  const navigate = useNavigate();
  const [show, setShow] = useState(false);
  const [error, setError] = useState("");
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Fields>({ resolver: zodResolver(schema) });
  useEffect(() => {
    document.title = `${projectConfig.productName} Administration | Sign in`;
    document
      .querySelector('meta[name="robots"]')
      ?.setAttribute("content", "noindex, nofollow");
    void initialize();
  }, [initialize]);
  if (auth.user?.role === "admin")
    return <Navigate to="/admin/dashboard" replace />;
  return (
    <main className="admin-login-page">
      <section className="admin-login-card">
        <Logo />
        <span className="site-eyebrow">ADMINISTRATION</span>
        <h1>Welcome back.</h1>
        <p className="muted">Authorised Trivia administrators only.</p>
        {!env.apiBaseUrl && (
          <p className="admin-status">
            Admin authentication is not connected. Live sign-in is unavailable.
          </p>
        )}
        <form
          noValidate
          onSubmit={handleSubmit(async (data) => {
            setError("");
            try {
              await auth.login(data.email, data.password);
              navigate("/admin/dashboard");
            } catch (e) {
              setError(
                e instanceof Error
                  ? e.message
                  : "Sign-in failed. Please try again.",
              );
            }
          })}
        >
          <label className="field">
            Email address
            <input
              {...register("email")}
              aria-label="Email address"
              type="email"
              autoComplete="username"
              aria-invalid={!!errors.email}
              aria-describedby={errors.email ? "admin-email-error" : undefined}
            />
            {errors.email && (
              <span id="admin-email-error" role="alert" className="field-error">
                {errors.email.message}
              </span>
            )}
          </label>
          <label className="field">
            Password
            <span className="admin-password">
              <input
                {...register("password")}
                aria-label="Password"
                type={show ? "text" : "password"}
                autoComplete="current-password"
                aria-invalid={!!errors.password}
                aria-describedby={
                  errors.password ? "admin-password-error" : undefined
                }
              />
              <button
                type="button"
                aria-label={show ? "Hide password" : "Show password"}
                aria-pressed={show}
                onClick={() => setShow(!show)}
              >
                {show ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </span>
            {errors.password && (
              <span
                id="admin-password-error"
                role="alert"
                className="field-error"
              >
                {errors.password.message}
              </span>
            )}
          </label>
          {error && (
            <p role="alert" className="field-error">
              {error}
            </p>
          )}
          <button className="btn" disabled={isSubmitting}>
            {isSubmitting ? "Signing in…" : "Sign in"}
          </button>
        </form>
        {env.adminDemo && (
          <>
            <p className="admin-status demo-entry">
              Development preview enabled. Sample data only; no live admin
              access.
            </p>
            <button
              className="btn secondary"
              onClick={() => {
                auth.loginDemo();
                navigate("/admin/dashboard");
              }}
            >
              Open admin demo
            </button>
          </>
        )}
        <nav aria-label="Legal information">
          <Link to="/terms">Terms &amp; Conditions</Link>
          {" · "}
          <Link to="/privacy">Privacy Policy</Link>
        </nav>
        <Link className="text-link" to="/">
          ← Back to Trivia
        </Link>
      </section>
    </main>
  );
}
