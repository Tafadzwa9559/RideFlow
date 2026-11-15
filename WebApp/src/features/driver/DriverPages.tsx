import { projectConfig } from "../../config/project";
import { earningsData } from "../../services/analytics.mock";
import { money } from "../../utils/format";
import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  CarFront,
  Check,
  FileCheck,
  MapPin,
  Power,
  Upload,
} from "lucide-react";
import { toast } from "sonner";
import { useAppStore } from "../../store/useAppStore";
import {
  Badge,
  Button,
  Empty,
  PageHeading,
} from "../../components/ui/primitives";
import {
  Notifications,
  Payments,
  Safety,
  Settings,
  Support,
} from "../shared/SharedPages";
import { KPIs, EarningsChart } from "../shared/Analytics";
import { Trips } from "../passenger/PassengerPages";
function Requests() {
  const [offer, setOffer] = useState("8.50");
  const [state, setState] = useState<
    "new" | "offered" | "rejected" | "accepted" | "started" | "complete"
  >("new");
  return (
    <>
      <PageHeading
        title="Your next opportunity"
        description="Explore how driver offers work. These are simulated requests."
      />
      <div className="notice">
        Live ride acceptance is disabled until backend identity review and
        approval. Demo controls below only change local state.
      </div>
      <section className="panel request-card">
        <div className="row between">
          <Badge>SIMULATED REQUEST</Badge>
          <strong>
            {state === "offered"
              ? "Offer sent"
              : state === "new"
                ? "New sample request"
                : state}
          </strong>
        </div>
        <h2>Avondale → Eastgate Centre</h2>
        <p className="muted">
          <MapPin size={15} /> Harare · Trivia Standard · Cash
        </p>
        <div className="request-fare">
          <span>Passenger’s proposed fare</span>
          <strong>{money(8.5)}</strong>
        </div>
        {state === "new" && (
          <>
            <label className="field">
              Your fare ({projectConfig.defaultCurrency})
              <input
                type="number"
                min="1"
                max="500"
                step=".5"
                value={offer}
                onChange={(e) => setOffer(e.target.value)}
              />
            </label>
            <div className="row wrap">
              <Button
                onClick={() => {
                  if (
                    Number(offer) < 1 ||
                    Number(offer) > 500 ||
                    !Number.isFinite(Number(offer))
                  ) {
                    toast.error(
                      `Offer must be between ${money(1)} and ${money(500)}.`,
                    );
                    return;
                  }
                  setState("offered");
                  toast.success(
                    "Demo offer submitted. No passenger was contacted.",
                  );
                }}
              >
                Send demo offer
              </Button>
              <Button
                className="secondary"
                onClick={() => {
                  setOffer("8.50");
                  setState("offered");
                }}
              >
                Accept proposed fare
              </Button>
              <Button
                className="danger-outline"
                onClick={() => setState("rejected")}
              >
                Reject
              </Button>
            </div>
          </>
        )}
        {state === "offered" && (
          <>
            <p>
              Your sample offer: {money(Number(offer))}. Waiting for simulated
              acceptance.
            </p>
            <div className="row wrap">
              <Button onClick={() => setState("accepted")}>
                Simulate passenger acceptance
              </Button>
              <Button className="secondary" onClick={() => setState("new")}>
                Withdraw offer
              </Button>
            </div>
          </>
        )}
        {state === "accepted" && (
          <>
            <p>
              Pickup: Avondale Shopping Centre. No live navigation is
              configured.
            </p>
            <Button onClick={() => setState("started")}>
              Simulate trip start
            </Button>
          </>
        )}
        {state === "started" && (
          <Button onClick={() => setState("complete")}>
            Complete demo trip
          </Button>
        )}
        {(state === "complete" || state === "rejected") && (
          <>
            <Empty
              title={
                state === "complete"
                  ? "Demo trip completed"
                  : "Request declined"
              }
            >
              No actual trip or payment occurred.
            </Empty>
            <Button className="secondary" onClick={() => setState("new")}>
              Reset sample request
            </Button>
          </>
        )}
      </section>
    </>
  );
}
function Documents({ vehicle = false }: { vehicle?: boolean }) {
  const [submitted, setSubmitted] = useState(false);
  return (
    <>
      <PageHeading
        title={
          vehicle
            ? "Your vehicle, ready for the road"
            : "Let’s get you road-ready"
        }
        description="Preview the driver application and document review process."
      />
      <div className="notice">
        Pending review · Live rides are unavailable. Do not upload real identity
        documents; this form keeps only sample filenames for this session.
      </div>
      <section className="panel onboarding">
        <h2>{vehicle ? "Vehicle information" : "Driver application"}</h2>
        {submitted ? (
          <>
            <Empty title="Demo application prepared">
              No files were uploaded. Secure document storage and backend review
              are required before real submissions.
            </Empty>
            <Button className="secondary" onClick={() => setSubmitted(false)}>
              Edit preview
            </Button>
          </>
        ) : (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setSubmitted(true);
              toast.success("Demo application preview prepared");
            }}
          >
            <div className="two-grid">
              {(vehicle
                ? [
                    "Vehicle make",
                    "Vehicle model",
                    "Year",
                    "Registration (sample only)",
                  ]
                : ["First name", "Last name", "Email", "Phone"]
              ).map((label) => (
                <label className="field" key={label}>
                  {label}
                  <input
                    required
                    type={
                      label === "Email"
                        ? "email"
                        : label === "Year"
                          ? "number"
                          : "text"
                    }
                    min={label === "Year" ? 2000 : undefined}
                    max={label === "Year" ? 2027 : undefined}
                  />
                </label>
              ))}
            </div>
            {(vehicle
              ? ["Vehicle registration", "Vehicle photographs"]
              : ["Driver’s licence", "National ID", "Supporting documents"]
            ).map((label) => (
              <label className="upload-field" key={label}>
                <Upload size={20} />
                <span>
                  {label}
                  <small>
                    Sample PDF, PNG or JPEG only. Files are never transmitted.
                  </small>
                </span>
                <input
                  aria-label={label}
                  type="file"
                  accept=".pdf,.png,.jpg,.jpeg"
                  required
                  onChange={(e) => {
                    if (
                      e.target.files?.[0] &&
                      e.target.files[0].size > 5 * 1024 * 1024
                    ) {
                      toast.error("Use a sample file under 5 MB.");
                      e.target.value = "";
                    }
                  }}
                />
              </label>
            ))}
            <Button>
              <FileCheck size={17} /> Preview submission
            </Button>
          </form>
        )}
      </section>
    </>
  );
}
export default function DriverPages() {
  const { page } = useParams();
  const online = useAppStore((s) => s.online);
  const setOnline = useAppStore((s) => s.setOnline);
  const commission = useAppStore((s) => s.commission);
  if (page === "notifications") return <Notifications />;
  if (page === "settings") return <Settings />;
  if (page === "support") return <Support />;
  if (page === "safety") return <Safety />;
  if (page === "wallet") return <Payments wallet />;
  if (page === "vehicle") return <Documents vehicle />;
  if (page === "documents") return <Documents />;
  if (page === "trips") return <Trips />;
  if (page === "requests" || page === "active") return <Requests />;
  if (page === "earnings") return <Earnings commission={commission} />;
  return (
    <>
      <PageHeading
        title="A good day starts with a choice."
        description="Your trips, opportunities and earnings at a glance."
        action={
          <Button
            className={online ? "" : "secondary"}
            onClick={() => setOnline(!online)}
          >
            <Power size={17} />
            {online ? "Demo online" : "Demo offline"}
          </Button>
        }
      />
      <div className="notice">
        Driver approval pending · Online status is simulated. You cannot accept
        live requests.
      </div>
      <KPIs
        items={[
          { label: "Today’s earnings", value: money(42) },
          { label: "Completed trips", value: "5" },
          { label: "This week", value: money(276) },
          {
            label: "Driver status",
            value: "In review",
            note: "Backend approval required",
          },
        ]}
      />
      <div className="dashboard-grid">
        <section className="panel">
          <div className="row between">
            <h2>Your week on the road</h2>
            <Badge>Sample earnings</Badge>
          </div>
          <EarningsChart />
          <Link className="text-link" to="/driver/earnings">
            View earnings breakdown →
          </Link>
        </section>
        <section className="panel">
          <CarFront size={32} className="green" />
          <h2>
            {online ? "Explore a sample opportunity" : "You set the pace."}
          </h2>
          <p className="muted">
            {online
              ? "A simulated trip is ready to explore. No real passenger is waiting."
              : "Switch on demo availability to explore the driver experience."}
          </p>
          <Link className="btn" to="/driver/requests">
            View demo requests →
          </Link>
          <hr />
          <p className="checkline">
            <Check size={17} /> Propose your fare
          </p>
          <p className="checkline">
            <Check size={17} /> Choose your requests
          </p>
          <Link className="text-link" to="/driver/documents">
            Complete application preview →
          </Link>
        </section>
      </div>
    </>
  );
}
function Earnings({ commission }: { commission: number }) {
  const [period, setPeriod] = useState("Weekly");
  const gross =
    period === "Daily"
      ? 42
      : period === "Monthly"
        ? 1104
        : earningsData.reduce((sum, d) => sum + d.gross, 0);
  return (
    <>
      <PageHeading
        title="See where your work takes you"
        description="A clear view of your sample earnings and deductions."
        action={
          <select
            aria-label="Earnings period"
            value={period}
            onChange={(e) => setPeriod(e.target.value)}
          >
            <option>Daily</option>
            <option>Weekly</option>
            <option>Monthly</option>
          </select>
        }
      />
      <KPIs
        items={[
          { label: `${period} gross`, value: money(gross) },
          {
            label: "Commission",
            value: money((gross * commission) / 100),
            note: `Demo rate: ${commission}%`,
          },
          {
            label: "Net earnings",
            value: money(gross * (1 - commission / 100)),
          },
          {
            label: "Completed trips",
            value:
              period === "Daily" ? "5" : period === "Monthly" ? "136" : "34",
          },
        ]}
      />
      <section className="panel">
        <h2>Sample weekly earnings</h2>
        <p className="muted">
          Chart shows a fixed seven-day demonstration dataset.
        </p>
        <EarningsChart />
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Day</th>
                <th>Trips</th>
                <th>Gross</th>
                <th>Commission</th>
                <th>Net</th>
              </tr>
            </thead>
            <tbody>
              {earningsData.map((d) => (
                <tr key={d.day}>
                  <td>{d.day}</td>
                  <td>{d.trips}</td>
                  <td>{money(d.gross)}</td>
                  <td>{money((d.gross * commission) / 100)}</td>
                  <td>{money(d.gross * (1 - commission / 100))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
