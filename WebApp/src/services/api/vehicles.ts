import { api } from "./client";
import type { Page, Vehicle } from "../../types/api";
export const vehiclesService = {
  list: (signal?: AbortSignal) =>
    api.get<Page<Vehicle>>("/vehicles/", { signal }),
  update: (id: string, data: Partial<Omit<Vehicle, "id" | "driver">>) =>
    api.patch<Vehicle>(`/vehicles/${encodeURIComponent(id)}/`, data),
};
