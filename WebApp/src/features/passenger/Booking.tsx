import { projectConfig } from "../../config/project";
import { formatDate } from "../../utils/localisation";
import { money } from "../../utils/format";
import { lazy, Suspense, useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import {
  ArrowDownUp,
  ArrowRight,
  Bookmark,
  CarFront,
  Check,
  ChevronRight,
  CircleHelp,
  MapPin,
  Navigation,
  ShieldCheck,
  Star,
  Users,
  Wallet,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { useAppStore } from "../../store/useAppStore";
import {
  categories,
  locations,
  mockRides,
  routeFixture,
} from "../../services/mock";
import {
  Badge,
  Button,
  Modal,
  PageHeading,
} from "../../components/ui/primitives";
import type { Location, RideStatus } from "../../types/domain";
const RideMap = lazy(() => import("../../components/maps/RideMap"));
const sequence: RideStatus[] = [
  "Driver assigned",
  "Driver arriving",
  "Driver arrived",
  "Ride in progress",
  "Ride completed",
];
export default function Booking() {
  const user = useAppStore((s) => s.user);
  const trips = useAppStore((s) => s.trips);
  const activeId = useAppStore((s) => s.activeId);
  const add = useAppStore((s) => s.addTrip);
  const update = useAppStore((s) => s.updateTrip);
  const notify = useAppStore((s) => s.notify);
  const saved = useAppStore((s) => s.saved);
  const save = useAppStore((s) => s.savePlace);
  const [draft] = useState(() => {
    try {
      const value: unknown = JSON.parse(
        sessionStorage.getItem("trivia-booking-draft") || "null",
      );
      if (
        typeof value === "object" &&
        value !== null &&
        "pickup" in value &&
        "destination" in value
      ) {
        return {
          pickup:
            locations.find((p) => p.name === value.pickup) ?? locations[0],
          destination:
            locations.find((p) => p.name === value.destination) ?? locations[1],
        };
      }
    } catch {
      /* Ignore an invalid browser draft. */
    }
    return { pickup: locations[0], destination: locations[1] };
  });
  const [pickup, setPickup] = useState(draft.pickup);
  const [destination, setDestination] = useState(draft.destination);
  useEffect(() => {
    sessionStorage.removeItem("trivia-booking-draft");
  }, []);
  const [category, setCategory] = useState(0);
  const [fare, setFare] = useState("8.50");
  const [selecting, setSelecting] = useState<"pickup" | "destination">(
    "pickup",
  );
  const [review, setReview] = useState(false);
  const [cancel, setCancel] = useState(false);
  const [rejected, setRejected] = useState<string[]>([]);
  const [rating, setRating] = useState(0);
  const [reviewText, setReviewText] = useState("");
  const lock = useRef(false);
  const trip = trips.find((t) => t.id === activeId);
  const active =
    trip && !["Ride cancelled", "Ride completed"].includes(trip.status);
  const offers = useQuery({
    queryKey: ["offers", trip?.id],
    queryFn: () => mockRides.offers(trip!.fare),
    enabled: !!trip && trip.status === "Offers received",
  });
  const fixture =
    pickup.name.startsWith("Avondale") &&
    destination.name.startsWith("Eastgate");
  function request() {
    if (pickup.lat === destination.lat && pickup.lng === destination.lng) {
      toast.error("Choose different pickup and destination locations.");
      return;
    }
    if (
      !Number.isFinite(Number(fare)) ||
      Number(fare) < 1 ||
      Number(fare) > 500
    ) {
      toast.error(`Propose a fare between ${money(1)} and ${money(500)}.`);
      return;
    }
    setReview(true);
  }
  function confirm() {
    const id = `TR-${Date.now().toString().slice(-6)}`;
    add({
      id,
      pickup,
      destination,
      category: categories[category].name,
      fare: Number(fare),
      status: "Offers received",
      date: new Date().toISOString(),
      payment: "Cash",
    });
    setRejected([]);
    setReview(false);
    notify(
      "Sample offers requested",
      "Compare simulated driver proposals for your demo journey.",
    );
    toast.success("Demo request created. No drivers were contacted.");
  }
  const select = (place: Location) =>
    selecting === "pickup" ? setPickup(place) : setDestination(place);
  return (
    <>
      <PageHeading
        eyebrow="LET’S MAKE YOUR NEXT MOVE"
        title={`Where to, ${user?.firstName}?`}
        description="A familiar route or somewhere new. Make the journey yours."
        action={
          <span className="date-label">
            <MapPin size={15} /> Harare, Zimbabwe
          </span>
        }
      />
      <div className="booking-grid">
        <section className="panel booking-panel">
          <div className="row between">
            <h2>{active ? "Your journey" : "Let’s get you there"}</h2>
            <Navigation size={21} className="green" />
          </div>
          {!active ? (
            <>
              <p className="muted small-copy">
                Set your route. Choose your ride. Name your fare.
              </p>
              <div className="location-fields">
                {(["pickup", "destination"] as const).map((type, i) => (
                  <label
                    className={`location-field ${selecting === type ? "selected" : ""}`}
                    key={type}
                  >
                    <span className={i ? "destination-dot" : "pickup-dot"} />
                    <span>
                      <small>{i ? "DROP-OFF" : "PICKUP"}</small>
                      <input
                        aria-label={type}
                        list="locations"
                        value={(type === "pickup" ? pickup : destination).name}
                        onFocus={() => setSelecting(type)}
                        onChange={(e) => {
                          const value = locations.find(
                            (l) => l.name === e.target.value,
                          );
                          select(
                            value || {
                              ...(type === "pickup" ? pickup : destination),
                              name: e.target.value,
                            },
                          );
                        }}
                        onBlur={() => {
                          const value =
                            type === "pickup" ? pickup : destination;
                          if (
                            !locations.some((l) => l.name === value.name) &&
                            !value.name.startsWith("Map pin") &&
                            value.name !== "Your current location"
                          ) {
                            toast.info(
                              "Choose a suggested location or select a map point.",
                            );
                            select(
                              type === "pickup" ? locations[0] : locations[1],
                            );
                          }
                        }}
                      />
                    </span>
                  </label>
                ))}
                <button
                  className="swap-button"
                  aria-label="Swap pickup and destination"
                  onClick={() => {
                    setPickup(destination);
                    setDestination(pickup);
                  }}
                >
                  <ArrowDownUp size={16} />
                </button>
                <datalist id="locations">
                  {locations.map((p) => (
                    <option key={p.name} value={p.name} />
                  ))}
                </datalist>
              </div>
              <p className="map-tip">
                <MapPin size={13} /> Click the map to set your {selecting}.
              </p>
              <div className="row between section-label">
                <strong>Choose your ride</strong>
                <span>{projectConfig.defaultCurrency}</span>
              </div>
              <div className="ride-options">
                {categories.map((c, i) => (
                  <button
                    className={`ride-option ${i === category ? "selected" : ""}`}
                    key={c.name}
                    onClick={() => {
                      setCategory(i);
                      setFare(c.fare.toFixed(2));
                    }}
                    aria-pressed={i === category}
                  >
                    <span className="vehicle-icon">
                      <CarFront size={32} strokeWidth={1.4} />
                    </span>
                    <span>
                      <strong>Trivia {c.name}</strong>
                      <small>
                        <Users size={11} /> {c.capacity} seats ·{" "}
                        {i === 0
                          ? "Everyday value"
                          : i === 1
                            ? "Extra comfort"
                            : "More room"}
                      </small>
                    </span>
                    <span>
                      <strong>{money(c.fare)}</strong>
                      <small>Demo fare</small>
                    </span>
                    {i === category ? (
                      <span className="radio active">
                        <Check size={10} />
                      </span>
                    ) : (
                      <span className="radio" />
                    )}
                  </button>
                ))}
              </div>
              <div className="fare-box">
                <div className="row between">
                  <span>
                    <strong>Your fare. Your choice.</strong>
                    <small>Propose a fare that works for you.</small>
                  </span>
                  <Wallet size={19} />
                </div>
                <div className="fare-input">
                  <span>{projectConfig.defaultCurrency}</span>
                  <input
                    type="number"
                    aria-label={`Proposed fare in ${projectConfig.defaultCurrency}`}
                    min="1"
                    max="500"
                    step="0.5"
                    value={fare}
                    onChange={(e) => setFare(e.target.value)}
                  />
                  <span>
                    Demo suggestion {money(categories[category].fare)}
                  </span>
                </div>
              </div>
              <div className="payment-row">
                <Wallet size={17} />
                <strong>Cash</strong>
                <span>Pay after your trip</span>
              </div>
              <Button className="full" onClick={request}>
                Review demo request <ArrowRight size={18} />
              </Button>
              <div className="booking-disclaimer">
                <ShieldCheck size={13} /> No payment or real ride will be
                requested.
              </div>
            </>
          ) : (
            <>
              <div className="trip-state">
                <span className="status-dot" />
                <strong>{trip.status}</strong>
                <Badge>SIMULATED</Badge>
              </div>
              <div className="trip-endpoints">
                <p>
                  <span className="pickup-dot" />
                  {trip.pickup.name}
                </p>
                <p>
                  <MapPin size={15} />
                  {trip.destination.name}
                </p>
              </div>
              <div className="row between">
                <span>Trivia {trip.category}</span>
                <strong>{money(trip.fare, trip.currency)}</strong>
              </div>
              {trip.status === "Offers received" ? (
                <>
                  <h3 className="section-label">Compare sample offers</h3>
                  <p className="muted small-copy">
                    No live availability, ratings or pickup estimates.
                  </p>
                  {offers.isPending ? (
                    <div className="skeleton">Preparing sample offers…</div>
                  ) : offers.isError ? (
                    <Button onClick={() => offers.refetch()}>
                      Retry sample offers
                    </Button>
                  ) : (
                    offers.data
                      ?.filter((o) => !rejected.includes(o.id))
                      .map((o) => (
                        <div className="offer" key={o.id}>
                          <div className="row">
                            <span className="avatar">{o.name[0]}</span>
                            <div>
                              <strong>{o.name}</strong>
                              <small>{o.vehicle}</small>
                            </div>
                            <strong>{money(o.fare)}</strong>
                          </div>
                          <p>
                            <ShieldCheck size={13} />{" "}
                            {o.verified
                              ? "Sample verification badge"
                              : "Unverified sample"}
                          </p>
                          <div className="row">
                            <Button
                              className="full"
                              onClick={() => {
                                if (
                                  lock.current ||
                                  trip.status !== "Offers received"
                                )
                                  return;
                                lock.current = true;
                                update(trip.id, {
                                  driver: o,
                                  fare: o.fare,
                                  status: "Driver assigned",
                                });
                                notify(
                                  "Sample driver assigned",
                                  `${o.name} is assigned in this simulation.`,
                                );
                                queueMicrotask(() => {
                                  lock.current = false;
                                });
                              }}
                            >
                              Accept offer
                            </Button>
                            <Button
                              className="secondary icon-btn"
                              aria-label={`Reject ${o.name}'s offer`}
                              onClick={() => setRejected([...rejected, o.id])}
                            >
                              <X size={17} />
                            </Button>
                          </div>
                        </div>
                      ))
                  )}
                  {rejected.length === 2 && (
                    <div className="notice">
                      All offers declined. Cancel this request to start again.
                    </div>
                  )}
                </>
              ) : (
                <>
                  <div className="assigned-driver">
                    <span className="avatar">{trip.driver?.name[0]}</span>
                    <h3>{trip.driver?.name}</h3>
                    <p>{trip.driver?.vehicle}</p>
                    <Badge>Sample driver · no live position</Badge>
                  </div>
                  <div className="timeline">
                    {sequence.map((s, i) => (
                      <div
                        className={
                          i <= sequence.indexOf(trip.status) ? "done" : ""
                        }
                        key={s}
                      >
                        <Check size={13} />
                        {s}
                      </div>
                    ))}
                  </div>
                  <Button
                    className="full"
                    onClick={() => {
                      const next = sequence[sequence.indexOf(trip.status) + 1];
                      if (next) {
                        update(trip.id, { status: next });
                        notify(
                          `Demo: ${next}`,
                          "A simulated trip event was applied.",
                        );
                      }
                    }}
                  >
                    Simulate{" "}
                    {sequence[sequence.indexOf(trip.status) + 1]?.toLowerCase()}{" "}
                    <ArrowRight size={16} />
                  </Button>
                  <Link className="text-link" to="/passenger/safety">
                    Trip safety & contact options <ShieldCheck size={15} />
                  </Link>
                </>
              )}
              <Button
                className="danger-outline full"
                onClick={() => setCancel(true)}
              >
                Cancel demo request
              </Button>
            </>
          )}
        </section>
        <div className="booking-map-column">
          <div className="map-card">
            <Suspense
              fallback={
                <div className="skeleton map-skeleton">
                  Loading interactive map…
                </div>
              }
            >
              <RideMap
                pickup={active ? trip.pickup : pickup}
                destination={active ? trip.destination : destination}
                onSelect={active ? undefined : select}
                showRoute
              />
            </Suspense>
            <div className="map-summary">
              <span className="icon-tile">
                <Navigation size={20} />
              </span>
              <div>
                <strong>
                  {fixture
                    ? "Avondale → City centre"
                    : "Your selected locations"}
                </strong>
                <small>
                  {fixture
                    ? `${routeFixture.distance} · ${routeFixture.duration} · curated demo fixture`
                    : "Road distance and travel time need a routing provider."}
                </small>
              </div>
              <Badge>DEMO ROUTE</Badge>
            </div>
          </div>
          <div className="saved-section">
            <div className="row between">
              <h3>Your familiar places</h3>
              <Link to="/passenger/saved">
                Manage <ChevronRight size={14} />
              </Link>
            </div>
            <div className="saved-grid">
              {saved.slice(0, 2).map((p, i) => (
                <button
                  key={p.name}
                  className="saved-place"
                  onClick={() => {
                    setDestination(p);
                    toast.success("Destination updated");
                  }}
                >
                  <span className="icon-tile">
                    <MapPin size={19} />
                  </span>
                  <span>
                    <strong>
                      {i === 0 ? "Your go-to spot" : "Another favourite"}
                    </strong>
                    <small>{p.name.split(",")[0]}</small>
                  </span>
                  <ChevronRight size={16} />
                </button>
              ))}
            </div>
            <button
              className="save-current"
              onClick={() => {
                save(destination);
                toast.success("Destination saved");
              }}
            >
              <Bookmark size={14} /> Save this destination
            </button>
          </div>
          <div className="journey-note">
            <ShieldCheck size={24} />
            <div>
              <strong>A little peace of mind goes a long way.</strong>
              <p>
                Review your driver, share your trip details and find safety
                tools in one place.
              </p>
            </div>
            <Link to="/passenger/safety" aria-label="Visit safety centre">
              <ArrowRight size={19} />
            </Link>
          </div>
        </div>
      </div>
      {trip?.status === "Ride completed" && !trip.rating && (
        <section className="panel review-panel">
          <h3>How was your demo journey?</h3>
          <p className="muted">Your feedback stays in this browser.</p>
          <div className="row">
            {[1, 2, 3, 4, 5].map((n) => (
              <button
                key={n}
                aria-label={`Rate ${n} stars`}
                aria-pressed={rating === n}
                className="star-button"
                onClick={() => setRating(n)}
              >
                <Star fill={n <= rating ? "#f59e0b" : "none"} color="#f59e0b" />
              </button>
            ))}
          </div>
          <textarea
            aria-label="Trip review"
            placeholder="Tell us about the journey (optional)"
            value={reviewText}
            onChange={(e) => setReviewText(e.target.value)}
          />
          <Button
            disabled={!rating}
            onClick={() => {
              update(trip.id, { rating, review: reviewText });
              toast.success("Demo review saved");
            }}
          >
            Save review
          </Button>
        </section>
      )}
      <section className="recent-trips">
        <div className="row between">
          <h2>A look at your recent journeys</h2>
          <Link className="text-link" to="/passenger/trips">
            View all trips <ArrowRight size={16} />
          </Link>
        </div>
        <div className="recent-grid">
          {trips.slice(0, 3).map((t) => (
            <Link
              className="recent-trip"
              key={t.id}
              to={`/passenger/trips?trip=${t.id}`}
            >
              <span className="icon-tile">
                <CarFront size={20} />
              </span>
              <div>
                <strong>{t.destination.name.split(",")[0]}</strong>
                <small>
                  {formatDate(t.date)} · {t.category}
                </small>
              </div>
              <span>
                <strong>{money(t.fare, t.currency)}</strong>
                <small
                  className={
                    t.status === "Ride cancelled" ? "cancelled" : "green"
                  }
                >
                  {t.status.replace("Ride ", "")}
                </small>
              </span>
            </Link>
          ))}
        </div>
      </section>
      <div className="help-note">
        <CircleHelp size={15} /> Need a hand?{" "}
        <Link to="/passenger/support">We’re here to help</Link>
        <span>All displayed journeys are sample data.</span>
      </div>
      {review && (
        <Modal
          title="Review your demo request"
          onClose={() => setReview(false)}
        >
          <p>
            {pickup.name} → {destination.name}
          </p>
          <p>
            Trivia {categories[category].name} · {money(Number(fare))} · Cash
          </p>
          <div className="notice">
            This creates a simulated request and sample driver offers. No real
            booking is made.
          </div>
          <Button className="full" onClick={confirm}>
            Confirm demo request <ArrowRight size={17} />
          </Button>
        </Modal>
      )}
      {cancel && (
        <Modal
          title="Cancel this demo request?"
          onClose={() => setCancel(false)}
        >
          <p>No cancellation fees apply in this preview.</p>
          <Button
            className="danger full"
            onClick={() => {
              if (trip) update(trip.id, { status: "Ride cancelled" });
              setCancel(false);
              toast.success("Demo request cancelled");
            }}
          >
            Confirm cancellation
          </Button>
        </Modal>
      )}
    </>
  );
}
