import { Link } from "react-router-dom";
import { Logo } from "../ui/primitives";
import { env } from "../../config/env";
import { projectConfig } from "../../config/project";
import legalManifest from "../../legal/content-digest.json";
import { currentYear } from "../../utils/localisation";
export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="site-container footer-grid">
        <div>
          <Logo />
          <p>{projectConfig.tagline}</p>
          <p className="developer-attribution">
            {legalManifest.attribution}
          </p>
          <small>
            Thoughtfully building the next way to move.
            <br />
            Starting with Zimbabwe.
            <br />
            Photography is illustrative. Subjects do not endorse Trivia.
          </small>
        </div>
        <div>
          <strong>Move with Trivia</strong>
          <Link to="/ride">For passengers</Link>
          <Link to="/drive">For drivers</Link>
          <Link to="/how-it-works">How it works</Link>
          <Link to="/download">Download the app</Link>
        </div>
        <div>
          <strong>Get to know us</strong>
          <Link to="/about">About Trivia</Link>
          <Link to="/safety">Safety approach</Link>
          <Link to="/faq">FAQs</Link>
          <Link to="/contact">Contact & support</Link>
          <a
            href="/photos/credits.json"
            target="_blank"
            rel="noopener noreferrer"
          >
            Photography credits ↗
          </a>
          {env.socialUrl && (
            <a href={env.socialUrl} target="_blank" rel="noopener noreferrer">
              Social updates ↗
            </a>
          )}
        </div>
        <div className="footer-note">
          <span className="site-eyebrow">MADE FOR EVERYDAY POSSIBILITIES</span>
          <p>
            A local beginning.
            <br />A wider horizon.
          </p>
          <small>
            App release destinations and service availability will be announced
            when confirmed.
          </small>
        </div>
        <div className="site-footer-bottom">
          <span>
            © {currentYear()} · {projectConfig.productName} —{" "}
            {projectConfig.tagline}
          </span>
          <Link to="/terms">Terms &amp; Conditions</Link>
          <Link to="/privacy">Privacy Policy</Link>
          <Link to="/admin/login">Admin Portal</Link>
        </div>
      </div>
    </footer>
  );
}
