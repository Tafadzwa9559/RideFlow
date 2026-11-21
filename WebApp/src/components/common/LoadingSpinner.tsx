import { useEffect, useState } from "react";

const MESSAGES = [
  "Finding drivers near you…",
  "Warming up the engine…",
  "Avoiding the potholes…",
  "Agreeing a fair fare…",
];

// Swap this for your exact brand green if it differs.
const CSS = `
.trivia-loader {
  --g: #10b981;
  position: fixed; inset: 0; z-index: 9999;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 28px; background: #fff; color: #111;
}
.trivia-loader__logo {
  display: flex; align-items: flex-end;
  font-size: clamp(56px, 14vw, 96px); font-weight: 800;
  letter-spacing: -0.04em; line-height: 1; color: var(--g);
}
.trivia-loader__logo > span { display: inline-block; animation: tl-wave 1.4s ease-in-out infinite; }
.trivia-loader__dot {
  position: relative; width: .2em; height: .2em; margin: 0 0 .08em .06em;
  border-radius: 50%; background: var(--g);
}
.trivia-loader__dot::after {
  content: ""; position: absolute; inset: 0; border-radius: 50%;
  border: 2px solid var(--g); animation: tl-ping 1.6s ease-out infinite;
}
.trivia-loader__road {
  position: relative; width: min(260px, 60vw); height: 2px;
  background: repeating-linear-gradient(90deg, #d4d4d8 0 10px, transparent 10px 18px);
}
.trivia-loader__road > span {
  position: absolute; top: 50%; left: 0; width: 14px; height: 14px; margin-top: -7px;
  border-radius: 50%; background: var(--g);
  animation: tl-drive 1.8s ease-in-out infinite alternate;
}
.trivia-loader__msg { margin: 0; font-size: 15px; color: #52525b; animation: tl-fade .4s ease both; }
.tl-sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }

@keyframes tl-wave { 0%, 60%, 100% { transform: translateY(0); } 30% { transform: translateY(-.12em); } }
@keyframes tl-ping { from { transform: scale(1); opacity: .8; } to { transform: scale(4); opacity: 0; } }
@keyframes tl-drive { from { left: 0; transform: scale(.7); } 50% { transform: scale(1.1); } to { left: calc(100% - 14px); transform: scale(.7); } }
@keyframes tl-fade { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }

@media (prefers-reduced-motion: reduce) {
  .trivia-loader *, .trivia-loader *::after { animation: none !important; }
}
`;

export default function LoadingSpinner() {
  const [i, setI] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setI((n) => (n + 1) % MESSAGES.length), 1800);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="trivia-loader" role="status" aria-live="polite">
      <style>{CSS}</style>
      <span className="tl-sr">Loading Trivia…</span>

      <div className="trivia-loader__logo" aria-hidden="true">
        {"trivia".split("").map((c, n) => (
          <span key={n} style={{ animationDelay: `${n * 0.09}s` }}>
            {c}
          </span>
        ))}
        <span className="trivia-loader__dot" />
      </div>

      <div className="trivia-loader__road" aria-hidden="true">
        <span />
      </div>

      <p key={i} className="trivia-loader__msg" aria-hidden="true">
        {MESSAGES[i]}
      </p>
    </div>
  );
}
