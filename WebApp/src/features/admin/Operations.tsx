import { useState } from "react";
import { toast } from "sonner";
import {
  Badge,
  Button,
  Empty,
  Modal,
  PageHeading,
} from "../../components/ui/primitives";
import { useAppStore } from "../../store/useAppStore";
import { money } from "../../utils/format";
export function Transactions() {
  const trips = useAppStore((s) => s.trips);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  const completed = trips.filter(
    (t) =>
      t.status === "Ride completed" &&
      `${t.id} ${t.payment}`.toLowerCase().includes(search.toLowerCase()),
  );
  const trip = completed.find((t) => t.id === selected);
  return (
    <>
      <PageHeading
        title="Payment activity"
        description="Illustrative cash records for completed sample journeys. These are not proof of payment."
      />
      <label className="field">
        Search payments
        <input value={search} onChange={(e) => setSearch(e.target.value)} />
      </label>
      <section className="panel table-panel">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Record</th>
                <th>Trip</th>
                <th>Amount</th>
                <th>Method</th>
                <th>Settlement</th>
                <th>Review</th>
              </tr>
            </thead>
            <tbody>
              {completed.map((t) => (
                <tr key={t.id}>
                  <td>DEMO-{t.id}</td>
                  <td>{t.id}</td>
                  <td>{money(t.fare, t.currency)}</td>
                  <td>{t.payment}</td>
                  <td>
                    <Badge>Not processed</Badge>
                  </td>
                  <td>
                    <Button
                      className="secondary"
                      onClick={() => setSelected(t.id)}
                    >
                      View payment
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!completed.length && (
          <Empty title="No matching payment records">
            Change the search to see sample entries.
          </Empty>
        )}
      </section>
      {trip && (
        <Modal title="Sample payment record" onClose={() => setSelected(null)}>
          <h3>{trip.id}</h3>
          <p>
            {trip.pickup.name} → {trip.destination.name}
          </p>
          <p>
            {money(trip.fare, trip.currency)} · {trip.payment}
          </p>
          <p className="notice">
            This is illustrative trip metadata. No transaction, refund or
            settlement occurred. Live reconciliation and payment actions require
            a provider-backed Django payment service.
          </p>
          <Button className="secondary" onClick={() => setSelected(null)}>
            Close record
          </Button>
        </Modal>
      )}
    </>
  );
}
export function Disputes() {
  const [records, setRecords] = useState([
    {
      id: "CASE-DEMO-01",
      trip: "TR-2041",
      subject: "Illustrative fare clarification",
      status: "Open",
      note: "Passenger asks how the proposed fare is displayed. This is a fabricated training example.",
    },
  ]);
  const [status, setStatus] = useState("All");
  const [selected, setSelected] = useState<string | null>(null);
  const [resolution, setResolution] = useState("");
  const [confirm, setConfirm] = useState(false);
  const record = records.find((r) => r.id === selected);
  return (
    <>
      <PageHeading
        title="Review concerns with care"
        description="Sample dispute workflow. No real support case or passenger report is received here."
      />
      <label className="field">
        Dispute status
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          {["All", "Open", "Resolved"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
      </label>
      <section className="panel table-panel">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Case</th>
                <th>Trip</th>
                <th>Concern</th>
                <th>Status</th>
                <th>Review</th>
              </tr>
            </thead>
            <tbody>
              {records
                .filter((r) => status === "All" || r.status === status)
                .map((r) => (
                  <tr key={r.id}>
                    <td>{r.id}</td>
                    <td>{r.trip}</td>
                    <td>{r.subject}</td>
                    <td>
                      <Badge>{r.status}</Badge>
                    </td>
                    <td>
                      <Button
                        className="secondary"
                        onClick={() => {
                          setSelected(r.id);
                          setResolution("");
                          setConfirm(false);
                        }}
                      >
                        Review dispute
                      </Button>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      </section>
      {record && (
        <Modal title="Review sample dispute" onClose={() => setSelected(null)}>
          <h3>{record.subject}</h3>
          <p>{record.note}</p>
          {record.status === "Resolved" ? (
            <p className="notice">Resolved in this preview session only.</p>
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                setConfirm(true);
              }}
            >
              <label className="field">
                Resolution note
                <textarea
                  required
                  minLength={10}
                  value={resolution}
                  onChange={(e) => {
                    setResolution(e.target.value);
                    setConfirm(false);
                  }}
                />
              </label>
              {confirm ? (
                <>
                  <p className="notice">
                    Confirm closing this sample case? No party will be notified.
                  </p>
                  <Button
                    type="button"
                    onClick={() => {
                      setRecords(
                        records.map((r) =>
                          r.id === record.id
                            ? { ...r, status: "Resolved", note: resolution }
                            : r,
                        ),
                      );
                      setSelected(null);
                      toast.success("Sample dispute resolved for this session");
                    }}
                  >
                    Confirm demo resolution
                  </Button>
                </>
              ) : (
                <Button>Review resolution</Button>
              )}
            </form>
          )}
        </Modal>
      )}
    </>
  );
}
