import { RouterProvider } from "react-router-dom";
import { router } from "../app/router";
export default function AppRouter() {
  return <RouterProvider router={router} />;
}
