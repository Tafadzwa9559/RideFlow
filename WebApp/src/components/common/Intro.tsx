const MOMENT_MS = 5000; // keep in step with SPLASH_MS in App.tsx

// Swap --g for your exact brand green if it differs.
const CSS = `
.tv-intro {
  --g: #10b981;
  position: fixed; inset: 0; overflow: hidden;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 22px; background: #fff; color: #111;
}
.tv-logo {
  position: relative; display: flex; align-items: flex-end;
  font-size: clamp(64px, 16vw, 120px); font-weight: 800;
  letter-spacing: -0.04em; line-height: 1; color: var(--g);
}
/* the road the dot rolls along */
.tv-ground {
  position: absolute; left: 50%; bottom: .1em; width: 100vw; height: 2px;
  transform: translateX(-50%);
  background: repeating-linear-gradient(90deg, #d4d4d8 0 12px, transparent 12px 22px);
  animation: tv-ground 3s ease both;
}
/* each letter drops in as the dot rolls past */
.tv-letter {
  display: inline-block;
  animation: tv-drop .6s cubic-bezier(.34, 1.56, .64, 1) var(--d) both;
}
/* the logo dot: rolls in from the left, then pops and pings */
.tv-dot {
  position: relative; width: .2em; height: .2em; margin: 0 0 .1em .06em;
  animation: tv-roll 2.2s cubic-bezier(.3, .6, .3, 1) both;
}
.tv-ball {
  position: absolute; inset: 0; border-radius: 50%; background: var(--g);
  animation: tv-spin 2.2s cubic-bezier(.3, .6, .3, 1) both, tv-pop .5s ease 2.2s both;
}
.tv-ball::after { /* a notch so you can see it rolling */
  content: ""; position: absolute; top: 14%; left: 38%; width: 24%; height: 24%;
  border-radius: 50%; background: #fff;
}
.tv-dot::after {
  content: ""; position: absolute; inset: 0; border-radius: 50%;
  border: 2px solid var(--g); opacity: 0;
  animation: tv-ping 1s ease-out 2.2s forwards;
}
/* tagline from the hero, one phrase at a time */
.tv-tagline {
  display: flex; flex-wrap: wrap; justify-content: center; gap: 0 .6em;
  font-size: clamp(16px, 3.6vw, 24px); font-weight: 600; margin: 0;
}
.tv-tagline span { animation: tv-rise .5s ease var(--d) both; }
.tv-sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }

@keyframes tv-ground { 0% { opacity: 0; } 10%, 70% { opacity: 1; } 100% { opacity: 0; } }
@keyframes tv-roll { from { transform: translateX(-100vw); } to { transform: translateX(0); } }
@keyframes tv-spin { from { rotate: 0deg; } to { rotate: 1080deg; } }
@keyframes tv-pop { 0%, 100% { scale: 1; } 40% { scale: 1.8; } }
@keyframes tv-ping { from { transform: scale(1); opacity: .8; } to { transform: scale(5); opacity: 0; } }
@keyframes tv-drop { from { opacity: 0; transform: translateY(-.35em) scale(.6); } to { opacity: 1; transform: none; } }
@keyframes tv-rise { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }

@media (prefers-reduced-motion: reduce) {
  .tv-intro *, .tv-intro *::after { animation: none !important; }
  .tv-ground { display: none; }
}
`;

const LETTERS = "trivia".split("");

export default function Intro() {
  return (
    <div className="tv-intro" role="status" data-duration={MOMENT_MS}>
      <style>{CSS}</style>
      <span className="tv-sr">Welcome to Trivia</span>

      <div className="tv-logo" aria-hidden="true">
        <span className="tv-ground" />
        {LETTERS.map((c, n) => (
          <span
            key={n}
            className="tv-letter"
            style={{ ["--d" as string]: `${0.9 + n * 0.22}s` }}
          >
            {c}
          </span>
        ))}
        <span className="tv-dot">
          <span className="tv-ball" />
        </span>
      </div>

      <p className="tv-tagline" aria-hidden="true">
        <span style={{ ["--d" as string]: "2.8s" }}>Your city.</span>
        <span style={{ ["--d" as string]: "3.15s" }}>Your ride.</span>
        <span style={{ ["--d" as string]: "3.5s" }}>Your choice.</span>
      </p>
    </div>
  );
}
