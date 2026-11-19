import { useState, type FormEvent } from "react";
import { Check, Circle, Eye, EyeOff } from "lucide-react";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../hooks/useAuth";
import { authService } from "../../services/api/auth";

const requirements: [string, (value: string) => boolean][] = [
  ["At least 8 characters", (value) => Array.from(value).length >= 8],
  ["One uppercase letter", (value) => /[A-Z]/.test(value)],
  ["One lowercase letter", (value) => /[a-z]/.test(value)],
  ["One number", (value) => /[0-9]/.test(value)],
  ["One special character", (value) => /[!-\/:-@\[-`{-~]/.test(value)],
];

function PasswordInput({
  label,
  value,
  onChange,
  current = false,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  current?: boolean;
  disabled: boolean;
}) {
  const [visible, show] = useState(false);
  return (
    <label className="field">
      {label}
      <span className="admin-password">
        <input
          type={visible ? "text" : "password"}
          autoComplete={current ? "current-password" : "new-password"}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          disabled={disabled}
          maxLength={256}
        />
        <button
          type="button"
          aria-label={`${visible ? "Hide" : "Show"} ${label.toLowerCase()}`}
          aria-pressed={visible}
          onClick={() => show(!visible)}
        >
          {visible ? <EyeOff size={18} /> : <Eye size={18} />}
        </button>
      </span>
    </label>
  );
}

export function ChangePasswordForm() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [current, setCurrent] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const strong = requirements.every(([, check]) => check(password));

  if (auth.demo) return null;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    if (!current || !strong || password !== confirmation) {
      setError("Enter your current password and a matching new password that meets the requirements.");
      return;
    }
    setError("");
    setBusy(true);
    try {
      await authService.changePassword(current, password, confirmation);
      auth.clearSession();
      toast.success("Password updated. Sign in with your new password.");
      navigate("/admin/login", { replace: true });
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : "Unable to update your password.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel">
      <h2>Change password</h2>
      <form onSubmit={(event) => void submit(event)}>
        <PasswordInput label="Current password" value={current} onChange={setCurrent} disabled={busy} current />
        <PasswordInput label="New password" value={password} onChange={setPassword} disabled={busy} />
        <ul aria-label="Password requirements" style={{ listStyle: "none", padding: 0 }}>
          {requirements.map(([label, check]) => {
            const passed = check(password);
            const Icon = passed ? Check : Circle;
            return (
              <li key={label} className={passed ? "" : "muted"} style={{ color: passed ? "#177447" : undefined, display: "flex", alignItems: "center", gap: 8 }}>
                <Icon size={14} aria-label={passed ? "Satisfied" : "Required"} /> {label}
              </li>
            );
          })}
        </ul>
        <PasswordInput label="Confirm new password" value={confirmation} onChange={setConfirmation} disabled={busy} />
        {error && <p className="field-error" role="alert">{error}</p>}
        <button className="btn" disabled={busy}>
          {busy ? "Updating password…" : "Change password"}
        </button>
      </form>
    </section>
  );
}
