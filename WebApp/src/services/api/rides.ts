import { api } from "./client";
import type { Trip, RideRequest, RideStatus } from "../../types/ride";
import type { Page } from "../../types/api";
export const ridesService = {
  list: (signal?: AbortSignal) => api.get<Page<Trip>>("/rides/", { signal }),
  request: (data: RideRequest) => api.post<Trip>("/rides/", data),
  get: (id: string) => api.get<Trip>(`/rides/${encodeURIComponent(id)}/`),
  acceptOffer: (rideId: string, offerId: string) =>
    api.post<Trip>(`/rides/${encodeURIComponent(rideId)}/accept-offer/`, {
      offer_id: offerId,
    }),
  transition: (id: string, status: RideStatus) =>
    api.post<Trip>(`/rides/${encodeURIComponent(id)}/transition/`, { status }),
  cancel: (id: string, reason: string) =>
    api.post<Trip>(`/rides/${encodeURIComponent(id)}/cancel/`, { reason }),
};
