import { Fragment } from "react";
import { Link } from "react-router-dom";
import { ArrowUpRight, ArrowRight } from "lucide-react";
import ScrollReveal from "../../components/common/ScrollReveal";
import FAQAccordion from "../../components/ui/FAQAccordion";
import AppDownload from "../../components/ui/AppDownload";
import AppPreview from "../../components/ui/AppPreview";
import Photo from "../../components/ui/Photo";
import { questions } from "./publicContent";
import { projectConfig } from "../../config/project";
export function FAQList({ limit }: { limit?: number }) {
  return <FAQAccordion items={questions.slice(0, limit)} />;
}
export function DownloadSection() {
  return (
    <ScrollReveal className="site-download-section">
      <div className="site-container download-grid">
        <ScrollReveal as="div" direction="left">
          <span className="site-eyebrow">MADE TO GO WITH YOU</span>
          <h2>
            Your next move.
            <br />
            One app away.
          </h2>
          <p>
            One planned app for passengers and drivers. Choose a platform to
            find confirmed release information.
          </p>
        </ScrollReveal>
        <AppDownload />
      </div>
    </ScrollReveal>
  );
}
export function RideCategories() {
  return (
    <div className="category-editorial">
      {[
        [
          "city-car",
          "Standard",
          "The everyday essential.",
          "A straightforward option for daily plans.",
        ],
        [
          "interior",
          "Comfort",
          "A little room to unwind.",
          "A comfortable choice for the journey ahead.",
        ],
        [
          "suv",
          "XL",
          "Make room for everyone.",
          "A larger option for travelling together.",
        ],
      ].map(([photo, title, line, copy], index) => (
        <ScrollReveal as="article" delay={index * 0.1} key={title}>
          <Photo
            name={photo as "city-car" | "interior" | "suv"}
            reveal={false}
          />
          <div>
            <h3>Trivia {title}</h3>
            <strong>{line}</strong>
            <p>{copy}</p>
          </div>
        </ScrollReveal>
      ))}
    </div>
  );
}
export default function Landing() {
  return (
    <>
      <section className="site-hero site-container photo-hero">
        <div className="hero-editorial">
          <ScrollReveal
            as="span"
            direction="down"
            distance={18}
            duration={0.45}
            className="site-eyebrow"
          >
            A NEW WAY TO MOVE. STARTING WITH ZIMBABWE.
          </ScrollReveal>
          <ScrollReveal as="h1" direction="up" distance={24} duration={0.55}>
            {projectConfig.heroHeadline
              .split(". ")
              .map((line, index, lines) => (
                <Fragment key={line}>
                  {line}
                  {index < lines.length - 1 && (
                    <>
                      .<br />
                    </>
                  )}
                </Fragment>
              ))}
          </ScrollReveal>
          <ScrollReveal as="p" delay={0.06} distance={24} duration={0.55}>
            {projectConfig.heroDescription}
          </ScrollReveal>
          <div className="site-actions">
            <ScrollReveal as="div" delay={0.1} distance={20} duration={0.5}>
              <Link className="site-button" to="/download">
                Download Trivia <ArrowUpRight size={18} />
              </Link>
            </ScrollReveal>
            <ScrollReveal as="div" delay={0.16} distance={20} duration={0.5}>
              <Link className="site-text-link" to="/how-it-works">
                How It Works <ArrowRight size={18} />
              </Link>
            </ScrollReveal>
          </div>
          <small className="hero-release">
            A mobile experience in development. Release details coming soon.
          </small>
        </div>
        <Photo name="city-car" parallax eager className="hero-photograph" />
      </section>
      <ScrollReveal
        direction="none"
        className="site-section site-container introduction-editorial"
        id="why-trivia"
      >
        <span className="site-eyebrow">THIS IS TRIVIA</span>
        <div>
          <h2>
            A little more freedom
            <br />
            in your everyday.
          </h2>
          <p>
            The morning commute. A visit across town. A change of plans. We’re
            building a simpler way to move through it all, with clear
            information and more room for choice.
          </p>
        </div>
        <div className="intro-values">
          <span>Flexible fares.</span>
          <span>Clear journey details.</span>
          <span>Your kind of ride.</span>
        </div>
      </ScrollReveal>
      <ScrollReveal direction="none" className="site-section site-soft">
        <div className="site-container story-split">
          <Photo name="navigation" direction="left" />
          <ScrollReveal as="div" direction="right">
            <span className="site-eyebrow">LESS EFFORT. MORE POSSIBILITY.</span>
            <h2>
              From your first tap
              <br />
              to your final stop.
            </h2>
            <ol className="concise-steps">
              {[
                [
                  "Tell the app where",
                  "Enter pickup and destination on your phone.",
                ],
                [
                  "Find your kind of ride",
                  "Choose a category, propose a fare and compare offers.",
                ],
                [
                  "Make your next move",
                  "Choose a driver and keep trip details close.",
                ],
              ].map(([title, copy], i) => (
                <ScrollReveal as="li" delay={i * 0.1} key={title}>
                  <span>0{i + 1}</span>
                  <div>
                    <h3>{title}</h3>
                    <p>{copy}</p>
                  </div>
                </ScrollReveal>
              ))}
            </ol>
            <Link className="site-text-link" to="/how-it-works">
              See how it works <ArrowUpRight size={17} />
            </Link>
          </ScrollReveal>
        </div>
      </ScrollReveal>
      <ScrollReveal
        direction="none"
        className="site-section site-container story-split passenger-editorial"
      >
        <ScrollReveal as="div" direction="left">
          <span className="site-eyebrow">RIDE WITH TRIVIA</span>
          <h2>
            Your plans.
            <br />
            Your kind of journey.
          </h2>
          <p>
            Everyday travel should feel straightforward. Explore a mobile
            experience designed around flexible fares, driver choice and the
            details you need before you go.
          </p>
          <Link className="site-text-link" to="/ride">
            Explore the passenger experience <ArrowUpRight size={17} />
          </Link>
        </ScrollReveal>
        <Photo name="passenger" />
      </ScrollReveal>
      <ScrollReveal direction="none" className="site-section site-soft">
        <div className="site-container story-split">
          <Photo name="driver" direction="left" />
          <ScrollReveal as="div" direction="right">
            <span className="site-eyebrow">DRIVE WITH TRIVIA</span>
            <h2>
              Your time.
              <br />
              New possibilities.
            </h2>
            <p>
              Review requests, agree on fares and understand your activity.
              Driver registration, verification and earnings tools are planned
              for the same mobile app.
            </p>
            <Link className="site-text-link" to="/drive">
              Explore driving opportunities <ArrowUpRight size={17} />
            </Link>
          </ScrollReveal>
        </div>
      </ScrollReveal>
      <ScrollReveal direction="none" className="site-section site-container">
        <ScrollReveal as="div" direction="up" className="section-heading">
          <span className="site-eyebrow">ROOM FOR YOUR PLANS</span>
          <h2>Different days. Different rides.</h2>
          <p>
            Planned categories. Photos are illustrative, not a fleet listing;
            eligibility and local availability will be confirmed before launch.
          </p>
        </ScrollReveal>
        <RideCategories />
      </ScrollReveal>
      <ScrollReveal direction="none" className="site-section site-soft">
        <div className="site-container story-split safety-editorial">
          <ScrollReveal as="div" direction="left">
            <span className="site-eyebrow">CONFIDENCE, AT EVERY TURN</span>
            <h2>
              Good journeys start
              <br />
              with clear information.
            </h2>
            <p>
              Our planned safety approach brings driver review, vehicle
              information and accessible reporting into focus. Learn what we’re
              building and the responsibilities we share.
            </p>
            <Link className="site-text-link" to="/safety">
              Our safety approach <ArrowUpRight size={17} />
            </Link>
            <small className="feature-status">
              Safety features are in development. This website is not an
              emergency or reporting service.
            </small>
          </ScrollReveal>
          <Photo name="safety" />
        </div>
      </ScrollReveal>
      <ScrollReveal
        direction="none"
        className="site-section site-container app-editorial"
      >
        <ScrollReveal as="div" direction="left">
          <span className="site-eyebrow">IN YOUR POCKET</span>
          <h2>
            Everyday details.
            <br />
            Thoughtfully together.
          </h2>
          <p>
            Fare proposals, driver offers, journey information and account tools
            — a planned mobile experience designed to give people more clarity.
          </p>
          <Link className="site-text-link" to="/download">
            Find the Trivia app <ArrowUpRight size={17} />
          </Link>
        </ScrollReveal>
        <AppPreview />
      </ScrollReveal>
      <DownloadSection />
      <ScrollReveal
        direction="none"
        className="site-section site-container faq-editorial"
      >
        <ScrollReveal as="div" direction="left">
          <span className="site-eyebrow">A FEW THINGS TO KNOW</span>
          <h2>
            Good questions.
            <br />
            Clear answers.
          </h2>
          <Link className="site-text-link" to="/faq">
            All FAQs <ArrowUpRight size={17} />
          </Link>
        </ScrollReveal>
        <FAQList limit={4} />
      </ScrollReveal>
    </>
  );
}
