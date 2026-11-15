import { api } from "./client";
import type { Offer } from "../../types/ride";
export const negotiationService = {
  list: (ride: string, signal?: AbortSignal) =>
    api.get<Offer[]>(`/rides/${encodeURIComponent(ride)}/offers/`, { signal }),
  propose: (ride: string, fare: number) =>
    api.post<Offer>(`/rides/${encodeURIComponent(ride)}/offers/`, { fare }),
  withdraw: (ride: string, offer: string) =>
    api.delete<void>(
      `/rides/${encodeURIComponent(ride)}/offers/${encodeURIComponent(offer)}/`,
    ),
};
