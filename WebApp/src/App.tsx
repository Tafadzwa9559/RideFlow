import { Suspense } from "react";
import AppRouter from "./routes/AppRouter";
import LoadingSpinner from "./components/common/LoadingSpinner";
export default function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <AppRouter />
    </Suspense>
  );
}
