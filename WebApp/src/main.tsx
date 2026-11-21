import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import "./typography.css";
import App from "./App.tsx";
import "./trivia-site-colors.css";
import "./trivia-colors.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
