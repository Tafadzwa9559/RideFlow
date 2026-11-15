import ScrollReveal from "../common/ScrollReveal";
import { CarFront, Home, MapPin, UserRound } from "lucide-react";
import { money } from "../../utils/format";
export default function AppPreview() {
  return (
    <ScrollReveal
      as="figure"
      direction="right"
      className="phone-scene"
      aria-label="Illustrative Trivia mobile app preview. Not a live booking interface."
    >
      <div className="scene-caption">
        <span /> YOUR JOURNEY, IN YOUR HANDS
      </div>
      <div className="phone-device">
        <div className="phone-status">
          <span>9:41</span>
          <span className="phone-island" />
          <span>▮▮ ▰</span>
        </div>
        <div className="phone-greeting">
          <span>
            trivia<span className="green">.</span>
          </span>
          <span className="phone-avatar">T</span>
        </div>
        <div className="phone-map">
          <span className="concept-map-label one">AVONDALE</span>
          <span className="concept-map-label two">HARARE</span>
          <svg viewBox="0 0 300 220" aria-hidden="true">
            <path
              d="M65 160 V90 H195 V45 H250"
              fill="none"
              stroke="#fff"
              strokeWidth="12"
            />
            <path
              d="M65 160 V90 H195 V45 H250"
              fill="none"
              stroke="#10b981"
              strokeWidth="5"
            />
            <circle
              cx="65"
              cy="160"
              r="8"
              fill="#10b981"
              stroke="white"
              strokeWidth="3"
            />
            <circle
              cx="250"
              cy="45"
              r="8"
              fill="#171717"
              stroke="white"
              strokeWidth="3"
            />
          </svg>
          <span className="sample-car">
            <CarFront size={21} />
          </span>
        </div>
        <div className="phone-sheet">
          <strong>Where will today take you?</strong>
          <div className="phone-location">
            <span className="green">●</span>
            <div>
              <small>PICKUP</small>Avondale Shopping Centre
            </div>
          </div>
          <div className="phone-location">
            <MapPin size={13} />
            <div>
              <small>DESTINATION</small>Eastgate Centre, Harare
            </div>
          </div>
          <div className="phone-rides">
            <span className="selected">
              <CarFront size={21} />
              Standard
            </span>
            <span>
              <CarFront size={21} />
              Comfort
            </span>
            <span>
              <CarFront size={21} />
              XL
            </span>
          </div>
          <div className="phone-fare">
            <span>
              Your fare proposal<small>Illustrative amount</small>
            </span>
            <strong>{money(8.5)}</strong>
          </div>
          <div className="phone-fake-button">Review driver offers →</div>
        </div>
        <div className="phone-tabs">
          <span>
            <Home size={16} />
            Home
          </span>
          <span>
            <CarFront size={16} />
            Trips
          </span>
          <span>
            <UserRound size={16} />
            Account
          </span>
        </div>
      </div>
      <figcaption>
        Illustrative app concept · Features in development
      </figcaption>
    </ScrollReveal>
  );
}
