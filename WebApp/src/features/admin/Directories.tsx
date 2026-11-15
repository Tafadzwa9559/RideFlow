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

export function PassengerDirectory() {
  const trips = useAppStore((s) => s.trips);
  const [search, setSearch] = useState("");
  const [accounts, setAccounts] = useState([
    {
      id: "P-101",
      name: "Tariro Demo",
      email: "passenger@trivia.test",
      active: true,
    },
    {
      id: "P-102",
      name: "Nyasha Sample",
      email: "nyasha@trivia.test",
      active: true,
    },
    {
      id: "P-103",
      name: "Chipo Sample",
      email: "chipo@trivia.test",
      active: false,
    },
  ]);
  const [selected, setSelected] = useState<string | null>(null);
  const account = accounts.find((a) => a.id === selected);
  const filtered = accounts.filter((a) =>
    `${a.name} ${a.email} ${a.id}`.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <>
      <PageHeading
        title="Your passenger community"
        description="Sample account directory. Changes last for this preview session only."
      />
      <label className="field">
        Search passengers
        <input value={search} onChange={(e) => setSearch(e.target.value)} />
      </label>
      <section className="panel table-panel">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Passenger</th>
                <th>Account</th>
                <th>Sample trips</th>
                <th>Manage</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr key={a.id}>
                  <td>
                    <strong>{a.name}</strong>
                    <small>{a.email}</small>
                  </td>
                  <td>
                    <Badge>{a.active ? "Active" : "Suspended"}</Badge>
                  </td>
                  <td>{a.id === "P-101" ? trips.length : 0}</td>
                  <td>
                    <Button
                      className="secondary"
                      onClick={() => setSelected(a.id)}
                    >
                      Manage passenger
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!filtered.length && (
          <Empty title="No passengers match">
            Try a different name or email.
          </Empty>
        )}
      </section>
      {account && (
        <Modal
          title="Manage sample passenger"
          onClose={() => setSelected(null)}
        >
          <h3>{account.name}</h3>
          <p>{account.email}</p>
          <p className="notice">
            This changes a local sample account only. Backend authorization and
            an audit trail are required for real account actions.
          </p>
          <Button
            onClick={() => {
              setAccounts(
                accounts.map((a) =>
                  a.id === account.id ? { ...a, active: !a.active } : a,
                ),
              );
              setSelected(null);
              toast.success("Sample account status updated for this session");
            }}
          >
            {account.active ? "Suspend demo account" : "Restore demo account"}
          </Button>
        </Modal>
      )}
    </>
  );
}

export function VehicleDirectory() {
  const applications = useAppStore((s) => s.applications);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("All");
  const [selected, setSelected] = useState<string | null>(null);
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [note, setNote] = useState("");
  const vehicle = applications.find((a) => a.id === selected);
  const filtered = applications.filter(
    (a) =>
      `${a.vehicle} ${a.name}`.toLowerCase().includes(search.toLowerCase()) &&
      (filter === "All" || a.status === filter),
  );
  return (
    <>
      <PageHeading
        title="The vehicles behind the journeys"
        description="Sample fleet register. Review states follow the associated driver application."
      />
      <div className="toolbar">
        <label className="field">
          Search vehicles
          <input value={search} onChange={(e) => setSearch(e.target.value)} />
        </label>
        <label className="field">
          Verification status
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            {["All", "Pending", "Approved", "Rejected", "Suspended"].map(
              (status) => (
                <option key={status}>{status}</option>
              ),
            )}
          </select>
        </label>
      </div>
      <section className="panel table-panel">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Vehicle</th>
                <th>Driver</th>
                <th>Review status</th>
                <th>Details</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr key={a.id}>
                  <td>
                    <strong>{a.vehicle}</strong>
                    <small>Sample registration · {a.id}</small>
                  </td>
                  <td>{a.name}</td>
                  <td>
                    <Badge>{a.status}</Badge>
                  </td>
                  <td>
                    <Button
                      className="secondary"
                      onClick={() => {
                        setSelected(a.id);
                        setNote(notes[a.id] || "");
                      }}
                    >
                      View vehicle
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!filtered.length && (
          <Empty title="No matching vehicles">
            Change the search or review status.
          </Empty>
        )}
      </section>
      {vehicle && (
        <Modal title="Sample vehicle record" onClose={() => setSelected(null)}>
          <h3>{vehicle.vehicle}</h3>
          <p>Assigned driver: {vehicle.name}</p>
          <Badge>{vehicle.status}</Badge>
          <p className="notice">
            Vehicle inspection, registration validation and document access
            require Django integration. Notes are session-only demo data.
          </p>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setNotes({ ...notes, [vehicle.id]: note.trim() });
              setSelected(null);
              toast.success("Demo vehicle note saved for this session");
            }}
          >
            <label className="field">
              Inspection note
              <textarea
                required
                minLength={10}
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
            </label>
            <Button>Save demo vehicle note</Button>
          </form>
        </Modal>
      )}
    </>
  );
}
