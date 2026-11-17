import { Suspense, useEffect, useState } from "react";
import AppRouter from "./routes/AppRouter";
import LoadingSpinner from "./components/common/LoadingSpinner";
import Intro from "./components/common/Intro";

const SPLASH_MS = 5000; // how long the Trivia screen stays fully visible
const FADE_MS = 500; // how long it takes to fade away

export default function App() {
  const [phase, setPhase] = useState<"show" | "fade" | "done">("show");

  useEffect(() => {
    const fadeTimer = setTimeout(() => setPhase("fade"), SPLASH_MS);
    const doneTimer = setTimeout(() => setPhase("done"), SPLASH_MS + FADE_MS);
    return () => {
      clearTimeout(fadeTimer);
      clearTimeout(doneTimer);
    };
  }, []);

  return (
    <>
      {/* The site loads behind the splash, so it is ready when the splash fades */}
      <Suspense fallback={<LoadingSpinner />}>
        <AppRouter />
      </Suspense>

      {phase !== "done" && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            zIndex: 9999,
            opacity: phase === "fade" ? 0 : 1,
            transition: `opacity ${FADE_MS}ms ease`,
            pointerEvents: phase === "fade" ? "none" : "auto",
          }}
        >
          <Intro />
        </div>
      )}
    </>
  );
}
