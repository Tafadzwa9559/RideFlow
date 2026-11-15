import { Link } from "react-router-dom";
import { ArrowUpRight } from "lucide-react";
import ScrollReveal from "../../components/common/ScrollReveal";
import AppDownload from "../../components/ui/AppDownload";
import AppPreview from "../../components/ui/AppPreview";
import Photo, { type PhotoName } from "../../components/ui/Photo";
import { DownloadSection, FAQList, RideCategories } from "./Landing";
import { driverSteps, passengerSteps } from "./publicContent";
import Contact from "./Contact";
import { projectConfig } from "../../config/project";
function PageHero({
  eyebrow,
  title,
  copy,
  photo,
  reverse = false,
}: {
  eyebrow: string;
  title: string;
  copy: string;
  photo?: PhotoName;
  reverse?: boolean;
}) {
  return (
    <header
      className={`site-container page-intro ${photo ? "page-intro-split" : ""} ${reverse ? "reverse-photo" : ""}`}
    >
      <ScrollReveal as="div" direction={reverse ? "right" : "left"}>
        <span className="site-eyebrow">{eyebrow}</span>
        <h1>{title}</h1>
        <p>{copy}</p>
        {photo && (
          <Link className="site-text-link" to="/download">
            Find the Trivia app <ArrowUpRight size={17} />
          </Link>
        )}
      </ScrollReveal>
      {photo && (
        <Photo
          name={photo}
          direction={reverse ? "left" : "right"}
          eager
          className="intro-visual"
        />
      )}
    </header>
  );
}
function FeatureRows({ items }: { items: [string, string][] }) {
  return (
    <div className="feature-rows">
      {items.map(([title, copy], i) => (
        <ScrollReveal
          as="article"
          delay={(i % 3) * 0.1}
          direction="up"
          key={title}
        >
          <span>0{i + 1}</span>
          <h2>{title}</h2>
          <p>{copy}</p>
        </ScrollReveal>
      ))}
    </div>
  );
}
export default function PublicPages({ pathname }: { pathname: string }) {
  if (pathname === "/contact") return <Contact />;
  if (pathname === "/download")
    return (
      <>
        <ScrollReveal className="site-container download-page">
          <ScrollReveal as="div" direction="left">
            <span className="site-eyebrow">TAKE YOUR NEXT STEP</span>
            <h1>
              Your journey.
              <br />
              In your pocket.
            </h1>
            <p>
              One Trivia app for passengers and drivers. Choose a platform to
              see its official download destination or release status.
            </p>
            <AppDownload />
            <p className="availability-note">
              Application downloads and live ride service are separate. Local
              service availability will be announced when confirmed.
            </p>
          </ScrollReveal>
          <AppPreview />
        </ScrollReveal>
        <ScrollReveal direction="none" className="site-section site-soft">
          <div className="site-container story-split">
            <Photo name="navigation" direction="left" />
            <ScrollReveal as="div" direction="left">
              <span className="site-eyebrow">MADE FOR YOUR PHONE</span>
              <h2>
                The next step
                <br />
                stays simple.
              </h2>
              <p>
                Choose an official, configured release destination when
                available. There is no need to create an account on this
                website, and downloads never start without your action.
              </p>
              <p>Passengers and drivers use the same planned Trivia app.</p>
            </ScrollReveal>
          </div>
        </ScrollReveal>
      </>
    );
  if (pathname === "/faq")
    return (
      <>
        <PageHero
          eyebrow="HELPFUL ANSWERS"
          title="A little clarity goes a long way."
          copy="Learn about our planned app experience, release availability and how Trivia will work."
        />
        <ScrollReveal
          direction="none"
          className="site-section site-container faq-page-editorial"
        >
          <aside>
            <Photo name="navigation" direction="left" />
            <h2>
              Good to know
              <br />
              before you go.
            </h2>
            <p>Can’t find your answer?</p>
            <Link className="site-text-link" to="/contact">
              Contact & support <ArrowUpRight size={17} />
            </Link>
          </aside>
          <FAQList />
        </ScrollReveal>
      </>
    );
  if (pathname === "/how-it-works")
    return (
      <>
        <PageHero
          eyebrow="LESS EFFORT. MORE POSSIBILITY."
          title="From your first tap to your final stop."
          copy="Everything happens in the Trivia mobile app. Here’s a look at the planned passenger and driver journeys."
        />
        <ScrollReveal className="site-container process-photography">
          <Photo name="navigation" direction="left" />
          <ScrollReveal as="div" direction="left">
            <span className="site-eyebrow">ONE APP. TWO WAYS TO MOVE.</span>
            <p>
              A familiar phone. A clearer plan. Take a look at the steps we’re
              building around passengers and drivers.
            </p>
          </ScrollReveal>
        </ScrollReveal>
        <ScrollReveal direction="none" className="site-section site-container">
          <div className="journey-grid">
            {[
              ["For passengers", passengerSteps],
              ["For drivers", driverSteps],
            ].map(([title, steps]) => (
              <article key={title as string}>
                <h2>{title as string}</h2>
                <ol className="journey-timeline">
                  {(steps as string[]).map((step, i) => (
                    <ScrollReveal as="li" delay={(i % 3) * 0.08} key={step}>
                      <span>{String(i + 1).padStart(2, "0")}</span>
                      <div>
                        <h3>{step}</h3>
                        <p>
                          {i === 0
                            ? "Choose your platform and check the official release destination."
                            : "Complete this step in the mobile app when the service becomes available."}
                        </p>
                      </div>
                    </ScrollReveal>
                  ))}
                </ol>
                <Link className="site-button" to="/download">
                  Download Trivia <ArrowUpRight size={17} />
                </Link>
              </article>
            ))}
          </div>
        </ScrollReveal>
        <DownloadSection />
      </>
    );
  if (pathname === "/ride")
    return (
      <>
        <PageHero
          eyebrow="RIDE WITH TRIVIA"
          title="Everyday plans. A better way to get there."
          copy="Convenient ride requests, flexible fares and clear journey details — designed for your phone."
          photo="passenger"
        />
        <ScrollReveal direction="none" className="site-section site-soft">
          <div className="site-container">
            <FeatureRows
              items={[
                [
                  "Request a ride, simply",
                  "Enter pickup and destination in the mobile app. Ride requests are not taken on this website.",
                ],
                [
                  "Have a say in your fare",
                  "Propose a fare, compare offers and choose what works for you in the planned mobile experience.",
                ],
                [
                  "Choose with confidence",
                  "Driver and vehicle information is planned to help you review an offer before deciding.",
                ],
                [
                  "Keep the details together",
                  "Trip visibility, past journeys and account tools are planned for your phone.",
                ],
                [
                  "Understand your payments",
                  "Payment options depend on confirmed providers. This website does not process payments.",
                ],
                [
                  "Know the next step",
                  "Keep pickup and destination information close at hand throughout the planned app journey.",
                ],
              ]}
            />
          </div>
        </ScrollReveal>
        <ScrollReveal direction="none" className="site-section site-container">
          <ScrollReveal as="div" direction="up" className="section-heading">
            <span className="site-eyebrow">A RIDE FOR YOUR KIND OF DAY</span>
            <h2>Choose what suits your plans.</h2>
            <p>
              Illustrative photos of planned categories; eligibility and
              availability will be confirmed.
            </p>
          </ScrollReveal>
          <RideCategories />
        </ScrollReveal>
        <DownloadSection />
      </>
    );
  if (pathname === "/drive")
    return (
      <>
        <PageHero
          eyebrow="DRIVE WITH TRIVIA"
          title="Your time. Your car. New possibilities."
          copy="Explore a flexible way to drive, with requests, fare negotiation and earnings tools in one planned mobile experience."
          photo="driver"
          reverse
        />
        <ScrollReveal direction="none" className="site-section site-container">
          <FeatureRows
            items={[
              [
                "Make room for your schedule",
                "Review requests and choose opportunities that work for you. Availability and earnings are not guaranteed.",
              ],
              [
                "Agree on a fare",
                "Accept a proposed fare or send a counteroffer through the mobile app before committing to a journey.",
              ],
              [
                "See your activity clearly",
                "Trip records and earnings information are planned to help you understand your driving activity.",
              ],
            ]}
          />
        </ScrollReveal>
        <ScrollReveal direction="none" className="site-section site-soft">
          <div className="site-container story-split">
            <ScrollReveal as="div" direction="left">
              <span className="site-eyebrow">GETTING ROAD-READY</span>
              <h2>
                Good journeys start
                <br />
                with preparation.
              </h2>
              <p>
                Planned onboarding includes identity, driving licence and
                vehicle registration review. Vehicle suitability and additional
                local requirements will be confirmed before launch.
              </p>
              <ol className="plain-requirements">
                {driverSteps.slice(0, 4).map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ol>
              <Link className="site-button" to="/download">
                Download the Driver App <ArrowUpRight size={17} />
              </Link>
              <small className="feature-status">
                The same Trivia app supports both audiences. There is no
                separate driver APK.
              </small>
            </ScrollReveal>
            <Photo name="interior" />
          </div>
        </ScrollReveal>
        <ScrollReveal
          direction="none"
          className="site-section site-container faq-editorial"
        >
          <ScrollReveal as="div" direction="left">
            <span className="site-eyebrow">
              BEFORE YOU TAKE THE DRIVER’S SEAT
            </span>
            <h2>A clearer start.</h2>
            <p>
              Drivers will be expected to maintain a suitable vehicle, protect
              account access, respect passengers and use support channels
              responsibly.
            </p>
          </ScrollReveal>
          <FAQList />
        </ScrollReveal>
        <DownloadSection />
      </>
    );
  if (pathname === "/safety")
    return (
      <>
        <PageHero
          eyebrow="CONFIDENCE, AT EVERY TURN"
          title="A shared approach to safer journeys."
          copy="Clear information, thoughtful checks and responsible use guide what we’re building. These are planned capabilities, not a claim of live safety coverage."
          photo="safety"
        />
        <ScrollReveal direction="none" className="site-section site-container">
          <FeatureRows
            items={[
              [
                "Driver verification",
                "Identity, licence and vehicle review are planned before approval. This website does not verify drivers or display private documents.",
              ],
              [
                "Know who you’re meeting",
                "Driver identification and vehicle details are planned to help passengers check their ride before boarding.",
              ],
              [
                "Keep your trip visible",
                "Journey information and trip status are planned inside the mobile app, subject to connection availability.",
              ],
              [
                "Reporting concerns",
                "In-app reporting and support processes are in development. Do not assume a report has been sent through this website.",
              ],
              [
                "Protect your account",
                "Keep verification codes private, use a strong password and install only from confirmed official destinations.",
              ],
              [
                "Respect goes both ways",
                "Passengers should check vehicle details and share accurate pickup information. Drivers should maintain their vehicle, respect passengers and follow road rules.",
              ],
            ]}
          />
          <div className="support-boundary">
            <h2>Clear support boundaries.</h2>
            <p>
              Confirmed support channels will be published when configured. This
              website is not monitored as an emergency service. For urgent
              danger, use appropriate local emergency channels.
            </p>
            <Link className="site-text-link" to="/contact">
              Contact & support →
            </Link>
          </div>
        </ScrollReveal>
        <DownloadSection />
      </>
    );
  return (
    <>
      <PageHero
        eyebrow="ABOUT TRIVIA"
        title="A local beginning. A wider horizon."
        copy="Trivia is a mobility platform being built for Zimbabwe, with a focus on convenience, flexibility and greater choice in everyday transportation."
      />
      <ScrollReveal className="site-container about-city">
        <Photo name="harare" wide parallax />
        <p className="photo-context">
          Harare, Zimbabwe · Illustrative city photography, not a
          service-coverage announcement.
        </p>
      </ScrollReveal>
      <ScrollReveal
        direction="none"
        className="site-section site-container mission-editorial"
      >
        <span className="site-eyebrow">WHY WE’RE BUILDING TRIVIA</span>
        <div>
          <ScrollReveal as="article" direction="left">
            <span className="editorial-label">OUR MISSION</span>
            <h2>
              To make everyday transportation more accessible, flexible, and
              convenient through smart technology.
            </h2>
          </ScrollReveal>
          <ScrollReveal as="article" direction="left">
            <span className="editorial-label">OUR VISION</span>
            <h2>
              To create a trusted mobility platform that gives people greater
              control over how they move.
            </h2>
          </ScrollReveal>
        </div>
      </ScrollReveal>
      <ScrollReveal direction="none" className="site-section site-soft">
        <div className="site-container story-split">
          <ScrollReveal as="div" direction="left">
            <span className="site-eyebrow">THE TECHNOLOGY BEHIND TRIVIA</span>
            <h2>
              Useful technology.
              <br />
              Human choices.
            </h2>
            <p>
              {projectConfig.productName} is a ride-hailing technology platform
              being developed by {projectConfig.developer}, a Zimbabwean
              technology company focused on building practical digital
              solutions.
            </p>
            <p>
              Trivia is the consumer-facing application brand.{" "}
              {projectConfig.developmentNotice} Our focus is straightforward
              trip information, flexible fares and tools designed for the people
              using them.
            </p>
          </ScrollReveal>
          <Photo name="suv" />
        </div>
      </ScrollReveal>
      <DownloadSection />
    </>
  );
}
