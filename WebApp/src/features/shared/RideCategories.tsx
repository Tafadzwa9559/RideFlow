import { useState } from "react";
import { Car, CarFront, Zap, Package, Route } from "lucide-react";
import Photo from "../../components/ui/Photo";

const SERVICES = [
  {
    id: "ride",
    label: "Ride",
    Icon: Car,
    copy: "The everyday way to get around. Enter your pickup and destination, propose a fare and compare offers from drivers before you decide. Planned for trips to work, to the shops or across town to see family.",
    points: [
      "Propose your own fare",
      "Compare driver offers",
      "See driver and car details before you go",
    ],
  },
  {
    id: "comfort",
    label: "Comfort",
    Icon: CarFront,
    copy: "For the trips where a little extra room matters. Comfort is planned for passengers who want a more relaxed ride, such as airport runs, special occasions or a long day out.",
    points: [
      "More space to relax",
      "Planned for longer or special trips",
      "The same flexible fares",
    ],
  },
  {
    id: "express",
    label: "Express",
    Icon: Zap,
    copy: "When time is short. Express is planned for urgent trips, with a focus on getting you moving quickly, so a last-minute meeting or a missed lift costs you less time.",
    points: [
      "Built for urgent trips",
      "A focus on nearby drivers",
      "Clear pickup details to keep things quick",
    ],
  },
  {
    id: "couriers",
    label: "Couriers",
    Icon: Package,
    copy: "Send what matters without leaving your day. Couriers is planned to let you send a parcel or an important document across the city with a driver, and keep the delivery details in one place.",
    points: [
      "Parcels and documents",
      "Pickup and drop-off details",
      "Delivery information in the app",
    ],
  },
  {
    id: "city-to-city",
    label: "City to city",
    Icon: Route,
    copy: "Plan longer journeys between towns and cities. Whether it is Harare to Bulawayo or a weekend trip home, City to city is planned to give you room to agree a fare for the distance, ahead of time.",
    points: [
      "Longer distances",
      "Agree the fare in advance",
      "Plan ahead, not on the spot",
    ],
  },
];

// Styles live here (class names start with rc-) so nothing in your CSS files can clash with them.
const CSS = `
.rc-picker {
  position: relative; isolation: isolate; overflow: hidden;
  min-height: 460px; padding: 20px; border-radius: 24px;
  background: #d1fae5; /* shows briefly while the photo loads */
}
.rc-bg { position: absolute; inset: -16px; z-index: -2; filter: blur(7px) saturate(1.15); }
.rc-bg figure, .rc-bg .photo-reveal-frame, .rc-bg .parallax-media {
  width: 100%; height: 100%; margin: 0; aspect-ratio: auto; border-radius: 0;
}
.rc-bg img { width: 100%; height: 100%; object-fit: cover; display: block; }
.rc-tint { position: absolute; inset: 0; z-index: -1; background: rgba(255, 255, 255, 0.12); }

.rc-tabs { display: flex; gap: 10px; overflow-x: auto; scroll-snap-type: x proximity; padding-bottom: 4px; }
.rc-tab {
  flex: 1 0 128px; display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 12px; min-height: 108px; padding: 16px 10px; border: 1px solid rgba(255, 255, 255, 0.55);
  border-radius: 16px; background: rgba(255, 255, 255, 0.45); color: #064e3b;
  font-size: 15px; font-weight: 600; white-space: nowrap; scroll-snap-align: start;
  -webkit-backdrop-filter: blur(6px); backdrop-filter: blur(6px);
}
.rc-tab:hover { background: rgba(255, 255, 255, 0.7); }
.rc-tab.is-active { background: #047857; border-color: #047857; color: #fff; box-shadow: 0 10px 26px rgba(4, 120, 87, 0.35); }

.rc-panel {
  display: grid; grid-template-columns: 1.3fr 1fr; gap: 28px; align-items: start;
  margin-top: 18px; padding: 26px 28px; border: 1px solid rgba(255, 255, 255, 0.6);
  border-radius: 18px; background: rgba(255, 255, 255, 0.72);
  -webkit-backdrop-filter: blur(10px); backdrop-filter: blur(10px);
}
.marketing.marketing .rc-panel h3 { color: #064e3b; font-size: 26px; margin: 0 0 10px; }
.marketing.marketing .rc-panel p { color: #1f3d33; margin: 0; max-width: 560px; }
.rc-points { list-style: none; margin: 0; padding: 0; display: grid; gap: 12px; }
.rc-points li { display: flex; align-items: flex-start; gap: 12px; color: #064e3b; font-weight: 500; line-height: 1.5; }
.rc-points li::before {
  content: "✓"; flex-shrink: 0; display: grid; place-items: center; width: 22px; height: 22px;
  margin-top: 1px; border-radius: 50%; background: #10b981; color: #052e22; font-size: 12px; font-weight: 800;
}
@media (max-width: 760px) {
  .rc-picker { padding: 14px; border-radius: 20px; min-height: 0; }
  .rc-tab { flex-basis: 108px; min-height: 96px; }
  .rc-panel { grid-template-columns: 1fr; gap: 18px; padding: 20px; }
}
`;

export default function RideCategories() {
  const [active, setActive] = useState(0);
  const current = SERVICES[active];

  return (
    <div className="rc-picker">
      <style>{CSS}</style>

      {/* fully blurred city photo behind everything */}
      <div className="rc-bg" aria-hidden="true">
        <Photo name="harare" reveal={false} />
      </div>
      <div className="rc-tint" aria-hidden="true" />

      <div className="rc-tabs" role="tablist" aria-label="Trivia ride types">
        {SERVICES.map(({ id, label, Icon }, i) => (
          <button
            key={id}
            type="button"
            role="tab"
            id={`rc-tab-${id}`}
            aria-selected={i === active}
            aria-controls="rc-panel"
            className={`rc-tab ${i === active ? "is-active" : ""}`}
            onClick={() => setActive(i)}
          >
            <Icon size={34} strokeWidth={1.6} aria-hidden="true" />
            <span>{label}</span>
          </button>
        ))}
      </div>

      <div
        id="rc-panel"
        role="tabpanel"
        aria-labelledby={`rc-tab-${current.id}`}
        className="rc-panel"
      >
        <div>
          <h3>Trivia {current.label}</h3>
          <p>{current.copy}</p>
        </div>
        <ul className="rc-points">
          {current.points.map((point) => (
            <li key={point}>{point}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}
