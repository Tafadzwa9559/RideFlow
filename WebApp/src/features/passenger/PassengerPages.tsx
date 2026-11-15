import { formatDate } from "../../utils/localisation";
import { downloadReceipt, money } from "../../utils/format";
import { useState } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import {
  CarFront,
  Download,
  MapPin,
  Plus,
  Search,
  Star,
  Trash2,
} from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAppStore } from "../../store/useAppStore";
import { locations, mockRides } from "../../services/mock";
import {
  Badge,
  Button,
  Empty,
  Modal,
  PageHeading,
} from "../../components/ui/primitives";
import {
  Notifications,
  Payments,
  Safety,
  Settings,
  Support,
} from "../shared/SharedPages";
export function Trips() {
  const trips = useAppStore((s) => s.trips);
  const update = useAppStore((s) => s.updateTrip);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("All");
  const [category, setCategory] = useState("All");
  const [date, setDate] = useState("");
  const [page, setPage] = useState(1);
  const [params, setParams] = useSearchParams();
  const trip = trips.find((t) => t.id === params.get("trip"));
  const [rating, setRating] = useState(5);
  const query = useQuery({
    queryKey: ["trip-history-demo"],
    queryFn: ({ signal }) => mockRides.list(signal),
  });
  const filtered = trips.filter(
    (t) =>
      (status === "All" ||
        (status === "Upcoming"
          ? !["Ride completed", "Ride cancelled"].includes(t.status)
          : t.status === status)) &&
      (category === "All" || category === t.category) &&
      (!date || t.date.slice(0, 10) === date) &&
      `${t.id} ${t.pickup.name} ${t.destination.name}`
        .toLowerCase()
        .includes(search.toLowerCase()),
  );
  return (
    <>
      <PageHeading
        title="Every journey has a story"
        description="Find your past trips, receipts and journey details."
      />
      <div className="toolbar">
        <label className="search-input">
          <Search size={17} />
          <input
            aria-label="Search trips"
            placeholder="Search locations or trip ID"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </label>
        <select
          aria-label="Filter trip status"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
        >
          {["All", "Upcoming", "Ride completed", "Ride cancelled"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <select
          aria-label="Filter category"
          value={category}
          onChange={(e) => {
            setCategory(e.target.value);
            setPage(1);
          }}
        >
          {["All", "Standard", "Comfort", "XL"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <input
          type="date"
          aria-label="Filter date"
          value={date}
          onChange={(e) => {
            setDate(e.target.value);
            setPage(1);
          }}
        />
      </div>
      <section className="panel table-panel">
        {query.isPending ? (
          <div className="skeleton">Loading sample journeys…</div>
        ) : query.isError ? (
          <Empty title="Couldn’t load journeys">
            <Button onClick={() => query.refetch()}>Try again</Button>
          </Empty>
        ) : filtered.length ? (
          <>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Journey</th>
                    <th>Date & category</th>
                    <th>Status</th>
                    <th>Fare</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.slice((page - 1) * 6, page * 6).map((t) => (
                    <tr key={t.id}>
                      <td>
                        <strong>{t.destination.name}</strong>
                        <small>From {t.pickup.name}</small>
                      </td>
                      <td>
                        {formatDate(t.date)}
                        <small>Trivia {t.category} · Sample</small>
                      </td>
                      <td>
                        <Badge>{t.status}</Badge>
                      </td>
                      <td>{money(t.fare, t.currency)}</td>
                      <td>
                        <Button
                          className="secondary"
                          onClick={() => setParams({ trip: t.id })}
                        >
                          View trip
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="pagination">
              <span>{filtered.length} sample trips</span>
              <Button
                className="secondary"
                disabled={page === 1}
                onClick={() => setPage(page - 1)}
              >
                Previous
              </Button>
              <span>{page}</span>
              <Button
                className="secondary"
                disabled={page * 6 >= filtered.length}
                onClick={() => setPage(page + 1)}
              >
                Next
              </Button>
            </div>
          </>
        ) : (
          <Empty title="No journeys found">
            Try another filter or plan a new demo ride.
          </Empty>
        )}
      </section>
      {trip && (
        <Modal title={`Journey ${trip.id}`} onClose={() => setParams({})}>
          <p>
            <MapPin size={15} /> {trip.pickup.name}
          </p>
          <p>→ {trip.destination.name}</p>
          <div className="row between">
            <Badge>{trip.status}</Badge>
            <strong>
              {money(trip.fare, trip.currency)} · {trip.payment}
            </strong>
          </div>
          <p className="muted">
            {trip.driver?.name || "No driver record"} · Trivia {trip.category}
          </p>
          <Button
            className="secondary"
            onClick={() =>
              downloadReceipt(
                `${trip.id}\n${trip.pickup.name} → ${trip.destination.name}\n${money(trip.fare, trip.currency)} · ${trip.payment}\n${trip.status}`,
              )
            }
          >
            <Download size={16} /> Download demo receipt
          </Button>
          {trip.status === "Ride completed" && (
            <div className="stack">
              <h3>
                {trip.rating
                  ? `Your rating: ${trip.rating}/5`
                  : "Review this demo journey"}
              </h3>
              {!trip.rating && (
                <>
                  <label className="field">
                    Rating
                    <select
                      value={rating}
                      onChange={(e) => setRating(Number(e.target.value))}
                    >
                      {[5, 4, 3, 2, 1].map((n) => (
                        <option value={n} key={n}>
                          {n} stars
                        </option>
                      ))}
                    </select>
                  </label>
                  <Button
                    onClick={() => {
                      update(trip.id, { rating });
                      toast.success("Sample rating saved");
                    }}
                  >
                    <Star size={15} /> Save rating
                  </Button>
                </>
              )}
            </div>
          )}
        </Modal>
      )}
    </>
  );
}
function Saved() {
  const saved = useAppStore((s) => s.saved);
  const save = useAppStore((s) => s.savePlace);
  const remove = useAppStore((s) => s.removePlace);
  const [add, setAdd] = useState(false);
  const [value, setValue] = useState(locations[0].name);
  return (
    <>
      <PageHeading
        title="Your familiar places"
        description="Make the places you love a little easier to get to."
        action={
          <Button onClick={() => setAdd(true)}>
            <Plus size={17} /> Add a place
          </Button>
        }
      />
      <div className="three-grid">
        {saved.map((p) => (
          <section className="panel" key={p.name}>
            <MapPin className="green" />
            <h3>{p.name}</h3>
            <p className="muted">
              {p.lat.toFixed(4)}, {p.lng.toFixed(4)}
            </p>
            <Button className="secondary" onClick={() => remove(p.name)}>
              <Trash2 size={15} /> Remove
            </Button>
          </section>
        ))}
      </div>
      {!saved.length && (
        <Empty title="A place for your favourites">
          Save a destination to find it here.
        </Empty>
      )}
      {add && (
        <Modal title="Save a place" onClose={() => setAdd(false)}>
          <label className="field">
            Location
            <select value={value} onChange={(e) => setValue(e.target.value)}>
              {locations.map((l) => (
                <option key={l.name}>{l.name}</option>
              ))}
            </select>
          </label>
          <Button
            onClick={() => {
              save(locations.find((l) => l.name === value)!);
              setAdd(false);
              toast.success("Place saved");
            }}
          >
            Save place
          </Button>
        </Modal>
      )}
    </>
  );
}
export default function PassengerPages() {
  const { page } = useParams();
  if (page === "trips") return <Trips />;
  if (page === "saved") return <Saved />;
  if (page === "payments") return <Payments />;
  if (page === "notifications") return <Notifications />;
  if (page === "safety") return <Safety />;
  if (page === "settings") return <Settings />;
  if (page === "support") return <Support />;
  return (
    <Empty title="Page not found">
      <CarFront /> Choose a destination from the navigation.
    </Empty>
  );
}
