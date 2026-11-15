export type { Trip, Offer, RideStatus, Location } from "./domain";
import type { Location } from "./domain";
export interface RideRequest {
  pickup: Location;
  destination: Location;
  category: string;
  fare: number;
  payment: string;
}
