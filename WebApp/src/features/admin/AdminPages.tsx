import { demoFareRules } from "../../config/project";
import { formatDateTime } from "../../utils/localisation";
import { Transactions, Disputes } from "./Operations";
import { PassengerDirectory, VehicleDirectory } from "./Directories";
import { downloadReceipt, money } from "../../utils/format";
import { useState } from "react";
import { Link } from "react-router-dom";
import { FileCheck, Search } from "lucide-react";
import { toast } from "sonner";
import { useAppStore } from "../../store/useAppStore";
import {
  Badge,
  Button,
  Modal,
  PageHeading,
} from "../../components/ui/primitives";
import { KPIs, EarningsChart } from "../shared/Analytics";
import { Notifications, Settings, Safety } from "../shared/SharedPages";
import { Trips } from "../passenger/PassengerPages";
import type { Application } from "../../types/domain";
function DriverManagement() {
  const applications = useAppStore((s) => s.applications);
  const review = useAppStore((s) => s.reviewApplication);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Application | null>(null);
  const [reason, setReason] = useState("");
  const [filter, setFilter] = useState("All");
  const [decision, setDecision] = useState<Application["status"] | null>(null);
  return (
    <>
      <PageHeading
        title="The people behind every journey"
        description="Review sample driver applications and verification status."
      />
      <div className="toolbar">
        <label className="search-input">
          <Search size={17} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search drivers"
            aria-label="Search drivers"
          />
        </label>
        <select
          aria-label="Driver status"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        >
          {["All", "Pending", "Approved", "Rejected", "Suspended"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
      </div>
      <section className="panel table-panel">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Driver</th>
                <th>Vehicle</th>
                <th>Status</th>
                <th>Review</th>
              </tr>
            </thead>
            <tbody>
              {applications
                .filter(
                  (a) =>
                    a.name.toLowerCase().includes(search.toLowerCase()) &&
                    (filter === "All" || a.status === filter),
                )
                .map((a) => (
                  <tr key={a.id}>
                    <td>
                      <strong>{a.name}</strong>
                      <small>{a.id}</small>
                    </td>
                    <td>{a.vehicle}</td>
                    <td>
                      <Badge>{a.status}</Badge>
                    </td>
                    <td>
                      <Button
                        className="secondary"
                        onClick={() => {
                          setSelected(a);
                          setReason("");
                          setDecision(null);
                        }}
                      >
                        Review profile
                      </Button>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      </section>
      {selected && (
        <Modal
          title="Review sample application"
          onClose={() => setSelected(null)}
        >
          <h3>{selected.name}</h3>
          <p>{selected.vehicle}</p>
          <div className="notice">
            Sample metadata only. No private documents are stored or available.
            Approval changes demo records only and does not grant live access.
          </div>
          <p>
            <FileCheck size={16} /> Licence · Demo document placeholder
          </p>
          <p>
            <FileCheck size={16} /> Vehicle registration · Demo document
            placeholder
          </p>
          <label className="field">
            Review reason
            <textarea
              value={reason}
              onChange={(e) => {
                setReason(e.target.value);
                setDecision(null);
              }}
              placeholder="Required for rejection or suspension"
            />
          </label>
          <div className="row wrap">
            {(["Approved", "Rejected", "Suspended", "Pending"] as const).map(
              (status) => (
                <Button
                  className={status === "Approved" ? "" : "secondary"}
                  key={status}
                  onClick={() => {
                    if (
                      (status === "Rejected" || status === "Suspended") &&
                      reason.trim().length < 10
                    ) {
                      toast.error(
                        "Provide a reason of at least 10 characters.",
                      );
                      return;
                    }
                    setDecision(status);
                  }}
                >
                  {status === "Approved"
                    ? "Approve"
                    : status === "Rejected"
                      ? "Reject"
                      : status === "Suspended"
                        ? "Suspend"
                        : "Return to review"}
                </Button>
              ),
            )}
          </div>
          {decision && (
            <div className="notice">
              <p>
                Confirm marking {selected.name} as {decision.toLowerCase()} in
                the demo? No live driver access changes.
              </p>
              <Button
                onClick={() => {
                  review(selected.id, decision, reason);
                  setSelected(null);
                  setDecision(null);
                  toast.success("Sample application decision saved");
                }}
              >
                Confirm demo decision
              </Button>
              <Button className="secondary" onClick={() => setDecision(null)}>
                Keep reviewing
              </Button>
            </div>
          )}
        </Modal>
      )}
    </>
  );
}
function Fares() {
  const commission = useAppStore((s) => s.commission);
  const setConfiguration = useAppStore((s) => s.setFareConfiguration);
  const savedRules = useAppStore((s) => s.fareRules);
  const savedLocation = useAppStore((s) => s.fareLocation);
  const [rules, setRules] = useState(savedRules);
  const [location, setLocation] = useState(savedLocation);
  const [confirm, setConfirm] = useState(false);
  const [value, setValue] = useState(commission);
  return (
    <>
      <PageHeading
        title="A fair framework for every journey"
        description="Preview fare and commission configuration."
      />
      <div className="notice">
        Draft configuration only. Live changes require backend validation and
        authorised administrative access.
      </div>
      <section className="panel onboarding">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setConfirm(true);
          }}
        >
          <h2>Suggested fare rules</h2>
          <div className="two-grid">
            {Object.keys(demoFareRules).map((label) => (
              <label className="field" key={label}>
                {label}
                <input
                  type="number"
                  required
                  min="0"
                  max="500"
                  step=".1"
                  value={rules[label] ?? 0}
                  onChange={(e) =>
                    setRules({ ...rules, [label]: Number(e.target.value) })
                  }
                />
              </label>
            ))}
          </div>
          <label className="field">
            Platform commission (%)
            <input
              type="number"
              required
              min="0"
              max="50"
              value={value}
              onChange={(e) => setValue(Number(e.target.value))}
            />
          </label>
          <label className="field">
            Service location draft
            <select
              value={location}
              onChange={(e) => setLocation(e.target.value)}
            >
              <option>Harare</option>
              <option>Bulawayo</option>
              <option>Mutare</option>
              <option>Gweru</option>
            </select>
          </label>
          <Button>Review configuration draft</Button>
        </form>
      </section>
      {confirm && (
        <Modal
          title="Confirm demo fare configuration"
          onClose={() => setConfirm(false)}
        >
          <p>
            Save the {location} fare draft with a {value}% platform commission?
          </p>
          <ul>
            {Object.entries(rules).map(([name, amount]) => (
              <li key={name}>
                {name}: {money(amount)}
              </li>
            ))}
          </ul>
          <p className="notice">
            This changes local sample configuration only. No live fare or
            commission is changed.
          </p>
          <Button
            onClick={() => {
              setConfiguration(rules, location, value);
              setConfirm(false);
              toast.success("Demo configuration saved locally");
            }}
          >
            Confirm demo configuration
          </Button>
        </Modal>
      )}
    </>
  );
}
export default function AdminPages({ page = "dashboard" }: { page?: string }) {
  const applications = useAppStore((s) => s.applications);
  const trips = useAppStore((s) => s.trips);
  const commission = useAppStore((s) => s.commission);
  const notices = useAppStore((s) => s.notices);
  if (page === "drivers" || page === "verification")
    return <DriverManagement />;
  if (page === "vehicles") return <VehicleDirectory />;
  if (page === "rides") return <Trips />;
  if (page === "fares") return <Fares />;
  if (page === "notifications") return <Notifications />;
  if (page === "settings")
    return (
      <>
        <Settings />
        <Fares />
      </>
    );
  if (page === "payments") return <Transactions />;
  if (page === "safety") return <Safety />;
  if (page === "disputes") return <Disputes />;
  if (page === "passengers") return <PassengerDirectory />;
  const complete = trips.filter((t) => t.status === "Ride completed");
  const revenue = complete.reduce((s, t) => s + t.fare, 0);
  return (
    <>
      <PageHeading
        eyebrow="TRIVIA OPERATIONS"
        title={
          page === "analytics"
            ? "A clearer picture of the platform"
            : "A thoughtful view of every moving part."
        }
        description="Sample operations data. Live platform activity is not connected."
        action={
          <Button
            className="secondary"
            onClick={() =>
              downloadReceipt(
                `SAMPLE OPERATIONS REPORT\nCompleted sample trips: ${complete.length}\nSample gross fares: ${money(revenue)}`,
                "trivia-demo-report.txt",
              )
            }
          >
            Export sample report
          </Button>
        }
      />
      <KPIs
        items={[
          { label: "Sample passengers", value: "3" },
          {
            label: "Ongoing rides",
            value: String(
              trips.filter(
                (t) => !["Ride completed", "Ride cancelled"].includes(t.status),
              ).length,
            ),
          },
          { label: "Sample drivers", value: String(applications.length) },
          {
            label: "Active drivers",
            value: "—",
            note: "Live availability not connected",
          },
          { label: "Completed trips", value: String(complete.length) },
          {
            label: "Cancelled trips",
            value: String(
              trips.filter((t) => t.status === "Ride cancelled").length,
            ),
          },
          {
            label: "Pending verifications",
            value: String(
              applications.filter((a) => a.status === "Pending").length,
            ),
          },
          { label: "Sample gross fares", value: money(revenue) },
          {
            label: "Sample commission",
            value: money((revenue * commission) / 100),
            note: `Illustrative ${commission}% commission`,
          },
        ]}
      />
      <div className="dashboard-grid">
        <section className="panel">
          <div className="row between">
            <h2>Activity at a glance</h2>
            <Badge>Illustrative weekly data</Badge>
          </div>
          <EarningsChart bars />
        </section>
        <section className="panel">
          <FileCheck className="green" size={30} />
          <h2>A little attention makes a difference.</h2>
          <p className="muted">
            {applications.filter((a) => a.status === "Pending").length} sample
            applications are awaiting review.
          </p>
          <Link className="btn" to="/admin/verification">
            Review applications →
          </Link>
          <hr />
          <Link className="text-link" to="/admin/fares">
            Manage fare drafts →
          </Link>
        </section>
      </div>
      <section className="panel">
        <h2>Recent sample events</h2>
        {notices.slice(0, 4).map((n) => (
          <div className="transaction" key={n.id}>
            <div>
              <strong>{n.title}</strong>
              <small>{n.body}</small>
            </div>
            <Badge>{n.read ? "Read" : "Unread"}</Badge>
          </div>
        ))}
      </section>
      <section className="panel">
        <div className="row between">
          <h2>Recent sample journeys</h2>
          <Link className="text-link" to="/admin/rides">
            View ride management →
          </Link>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Trip</th>
                <th>Destination</th>
                <th>Status</th>
                <th>Fare</th>
              </tr>
            </thead>
            <tbody>
              {trips.slice(0, 5).map((t) => (
                <tr key={t.id}>
                  <td>
                    {t.id}
                    <small>{formatDateTime(t.date)}</small>
                  </td>
                  <td>{t.destination.name}</td>
                  <td>
                    <Badge>{t.status}</Badge>
                  </td>
                  <td>{money(t.fare, t.currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
