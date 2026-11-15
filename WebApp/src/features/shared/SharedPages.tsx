import { projectConfig, paymentMethods } from "../../config/project";
import { normalisePhone, formatDate } from "../../utils/localisation";
import { downloadReceipt, money } from "../../utils/format";
import { useState } from "react";
import { Link } from "react-router-dom";
import {
  Bell,
  Check,
  CreditCard,
  Download,
  Plus,
  ShieldCheck,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";
import { useAppStore } from "../../store/useAppStore";
import {
  Badge,
  Button,
  Empty,
  Modal,
  PageHeading,
} from "../../components/ui/primitives";
export function Notifications() {
  const notices = useAppStore((s) => s.notices);
  const read = useAppStore((s) => s.readNotice);
  return (
    <>
      <PageHeading
        title="Your notifications"
        description="The little updates that keep your journey moving."
        action={
          <Button
            className="secondary"
            onClick={() => notices.forEach((n) => read(n.id))}
          >
            Mark all as read <Check size={16} />
          </Button>
        }
      />
      <section className="panel list-panel">
        {notices.length ? (
          notices.map((n) => (
            <button
              className={`notification-row ${n.read ? "read" : ""}`}
              key={n.id}
              onClick={() => read(n.id)}
            >
              <span className="icon-tile">
                <Bell size={19} />
              </span>
              <span>
                <strong>{n.title}</strong>
                <p>{n.body}</p>
                <small>
                  {n.read ? "Read" : "Unread · click to mark as read"}
                </small>
              </span>
              {!n.read && <span className="status-dot" />}
            </button>
          ))
        ) : (
          <Empty title="All caught up">New updates will appear here.</Empty>
        )}
      </section>
    </>
  );
}
export function Settings() {
  const user = useAppStore((s) => s.user);
  const update = useAppStore((s) => s.updateUser);
  const [name, setName] = useState(user?.firstName || "");
  const [last, setLast] = useState(user?.lastName || "");
  const [phone, setPhone] = useState(user?.phone || "");
  const [email, setEmail] = useState(user?.email || "");
  const [compact, setCompact] = useState(false);
  return (
    <>
      <PageHeading
        title="Make yourself at home"
        description="Manage your profile and account preferences."
      />
      <div className="two-grid">
        <section className="panel">
          <h2>Personal information</h2>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              const normalisedPhone = normalisePhone(phone);
              if (!normalisedPhone) {
                toast.error(
                  "Enter a valid Zimbabwe or international phone number.",
                );
                return;
              }
              if (!name.trim() || !last.trim()) {
                toast.error("Enter your first and last name.");
                return;
              }
              update({
                firstName: name.trim(),
                lastName: last.trim(),
                phone: normalisedPhone,
                email,
              });
              toast.success("Demo profile saved in this browser");
            }}
          >
            <div className="two-grid">
              <label className="field">
                First name
                <input
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </label>
              <label className="field">
                Last name
                <input
                  required
                  value={last}
                  onChange={(e) => setLast(e.target.value)}
                />
              </label>
            </div>
            <label className="field">
              Email
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </label>
            <label className="field">
              Phone
              <input
                type="tel"
                required
                autoComplete="tel"
                aria-describedby="profile-phone-help"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
            </label>
            <small id="profile-phone-help">
              Zimbabwe: {projectConfig.dialCode} or a local number starting with
              0. For other countries, include the international dialling code.
            </small>
            <Button>Save demo profile</Button>
          </form>
        </section>
        <div className="stack">
          <section className="panel">
            <h2>Account & security</h2>
            <p className="muted">
              Demo verification does not verify your identity.
            </p>
            <p className="muted">
              Administrator password resets, multi-factor authentication and
              verification must be managed by the authorised Django identity
              service. No public account registration is available on this
              website.
            </p>
          </section>
          <section className="panel">
            <h2>Preferences</h2>
            <label className="checkline">
              <input
                type="checkbox"
                checked={compact}
                onChange={(e) => {
                  setCompact(e.target.checked);
                  document.documentElement.classList.toggle(
                    "compact-view",
                    e.target.checked,
                  );
                }}
              />{" "}
              Reduce detail in this preview
            </label>
            <p className="muted">
              {compact
                ? "A quieter view selected for this session."
                : "Full journey detail selected."}
            </p>
            <p className="muted">
              Currency: {projectConfig.defaultCurrency} · Language:{" "}
              {projectConfig.languageName}
              <br />
              Timezone: {projectConfig.timezone}
            </p>
          </section>
        </div>
      </div>
    </>
  );
}
export function Payments({ wallet = false }: { wallet?: boolean }) {
  const trips = useAppStore((s) => s.trips);
  const [refund, setRefund] = useState(false);
  return (
    <>
      <PageHeading
        title={wallet ? "Your wallet" : "Simple, clear payments"}
        description="Keep your payment preferences and transaction records together."
      />
      <div className="two-grid">
        <section className="panel">
          <h2>{wallet ? "Sample balance" : "Payment methods"}</h2>
          {wallet && <p className="big-number">{money(0)}</p>}
          <div className="payment-method">
            <CreditCard />
            <div>
              <strong>Cash</strong>
              <small>Selected for demo trips</small>
            </div>
            <Badge>Available in demo</Badge>
          </div>
          {paymentMethods
            .filter((method) => method.id !== "cash")
            .map((method) => (
              <div className="payment-method" key={method.id}>
                <CreditCard />
                <div>
                  <strong>{method.label}</strong>
                  <small>Provider integration required</small>
                </div>
                <Button className="secondary" disabled>
                  Not connected
                </Button>
              </div>
            ))}
          <div className="notice">
            No payment is processed. Card entry is handled only through a future
            provider-hosted checkout. No card details are collected here.
          </div>
        </section>
        <section className="panel">
          <h2>Sample transaction history</h2>
          {trips
            .filter((t) => t.status === "Ride completed")
            .map((t) => (
              <div className="transaction" key={t.id}>
                <div>
                  <strong>{t.id}</strong>
                  <small>{formatDate(t.date)} · Cash · Demo</small>
                </div>
                <strong>{money(t.fare, t.currency)}</strong>
                <Button
                  className="secondary icon-btn"
                  aria-label={`Download receipt ${t.id}`}
                  onClick={() =>
                    downloadReceipt(
                      `${t.id}\n${t.pickup.name} → ${t.destination.name}\n${money(t.fare, t.currency)} · Cash`,
                    )
                  }
                >
                  <Download size={17} />
                </Button>
              </div>
            ))}
          <Button className="secondary" onClick={() => setRefund(true)}>
            Preview a refund request
          </Button>
        </section>
      </div>
      {refund && (
        <Modal title="Demo refund request" onClose={() => setRefund(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              toast.success(
                "Demo refund request recorded locally. No refund was issued.",
              );
              setRefund(false);
            }}
          >
            <label className="field">
              Trip
              <select required>
                {trips
                  .filter((t) => t.status === "Ride completed")
                  .map((t) => (
                    <option key={t.id}>{t.id}</option>
                  ))}
              </select>
            </label>
            <label className="field">
              Reason
              <textarea
                required
                minLength={10}
                placeholder="Describe the issue (at least 10 characters)"
              />
            </label>
            <Button>Save demo request</Button>
          </form>
        </Modal>
      )}
    </>
  );
}
export function Safety() {
  const [contacts, setContacts] = useState<{ name: string; phone: string }[]>(
    [],
  );
  const [add, setAdd] = useState(false);
  const [report, setReport] = useState(false);
  const trip = useAppStore((s) => s.trips.find((t) => t.id === s.activeId));
  return (
    <>
      <PageHeading
        title="Confidence, at every turn"
        description="Your safety tools, together in one place."
      />
      <div className="notice">
        Emergency assistance is not configured or operational in this
        development preview.
      </div>
      <div className="two-grid">
        <section className="panel">
          <ShieldCheck className="green" size={32} />
          <h2>Your journey details</h2>
          <p className="muted">
            Share a summary of your demo journey. This does not create a public
            tracking link.
          </p>
          <Button
            className="secondary"
            disabled={!trip}
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(
                  `TRIVIA DEMO TRIP ${trip?.id}\n${trip?.pickup.name} → ${trip?.destination.name}\n${trip?.status}`,
                );
                toast.success("Demo trip summary copied");
              } catch {
                toast.error(
                  "Clipboard unavailable. View trip history for the trip details.",
                );
              }
            }}
          >
            Copy demo trip details
          </Button>
          <h3>Need to report a concern?</h3>
          <p className="muted">
            Preview the reporting experience for a driver, passenger or trip
            dispute.
          </p>
          <Button className="secondary" onClick={() => setReport(true)}>
            Report an issue
          </Button>
        </section>
        <section className="panel">
          <div className="row between">
            <h2>Emergency contacts</h2>
            <Button className="secondary" onClick={() => setAdd(true)}>
              <Plus size={16} /> Add
            </Button>
          </div>
          {contacts.length ? (
            contacts.map((c, i) => (
              <div className="transaction" key={i}>
                <div>
                  <strong>{c.name}</strong>
                  <small>{c.phone}</small>
                </div>
                <Button
                  className="secondary icon-btn"
                  aria-label={`Remove ${c.name}`}
                  onClick={() =>
                    setContacts(contacts.filter((_, index) => index !== i))
                  }
                >
                  <Trash2 size={16} />
                </Button>
              </div>
            ))
          ) : (
            <Empty title="Keep someone close">
              Add a contact for this preview session. Contacts are not
              transmitted.
            </Empty>
          )}
          <p className="muted">
            Always confirm the vehicle and driver match your trip details before
            boarding.
          </p>
        </section>
      </div>
      {add && (
        <Modal title="Add a demo contact" onClose={() => setAdd(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              const d = new FormData(e.currentTarget);
              const contactPhone = normalisePhone(String(d.get("phone")));
              if (!contactPhone) {
                toast.error(
                  "Enter a valid Zimbabwe or international phone number.",
                );
                return;
              }
              setContacts([
                ...contacts,
                { name: String(d.get("name")), phone: contactPhone },
              ]);
              setAdd(false);
            }}
          >
            <label className="field">
              Name
              <input name="name" required />
            </label>
            <label className="field">
              Phone
              <input
                name="phone"
                type="tel"
                autoComplete="tel"
                aria-label="Contact phone number"
                required
              />
            </label>
            <Button>Add contact</Button>
          </form>
        </Modal>
      )}
      {report && (
        <Modal title="Demo safety report" onClose={() => setReport(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              toast.success(
                "Demo report acknowledged. No report was sent to an operations team.",
              );
              setReport(false);
            }}
          >
            <label className="field">
              Report type
              <select>
                <option>Report driver</option>
                <option>Report passenger</option>
                <option>Trip dispute</option>
              </select>
            </label>
            <label className="field">
              What happened?
              <textarea required minLength={10} />
            </label>
            <p className="muted">
              This form is a preview and is not monitored.
            </p>
            <Button>Preview submission</Button>
          </form>
        </Modal>
      )}
    </>
  );
}
export function Support() {
  return (
    <>
      <PageHeading
        title="A little help along the way"
        description="Answers to the questions that matter."
      />
      <section className="panel support-panel">
        {[
          [
            "Can I book a real ride?",
            "This frontend is a demonstration. Live dispatch and driver availability will be provided by the Django backend.",
          ],
          [
            "How are fares agreed?",
            "A passenger proposes a fare. A driver accepts or makes an offer. The passenger selects one offer before the journey begins.",
          ],
          [
            "Where is my payment?",
            "No funds move in this preview. Cash is shown as a sample payment preference.",
          ],
          [
            "How do I report an incident?",
            "The safety centre includes a demo report form. It is not monitored and should not be used for an emergency.",
          ],
        ].map(([q, a]) => (
          <details key={q}>
            <summary>{q}</summary>
            <p>{a}</p>
          </details>
        ))}
        <Link className="text-link" to="../safety">
          Open safety centre →
        </Link>
      </section>
    </>
  );
}
