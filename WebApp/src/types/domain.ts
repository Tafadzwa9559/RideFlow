export type Role = "passenger" | "driver" | "admin";
export type User = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  role: Role;
};
export type Location = { name: string; lat: number; lng: number };
export type RideStatus =
  | "Offers received"
  | "Driver assigned"
  | "Driver arriving"
  | "Driver arrived"
  | "Ride in progress"
  | "Ride completed"
  | "Ride cancelled";
export type Offer = {
  id: string;
  name: string;
  vehicle: string;
  fare: number;
  verified: boolean;
};
export type Trip = {
  id: string;
  pickup: Location;
  destination: Location;
  category: string;
  fare: number;
  status: RideStatus;
  date: string;
  currency?: string;
  driver?: Offer;
  rating?: number;
  review?: string;
  payment: string;
};
export type Notice = { id: string; title: string; body: string; read: boolean };
export type Application = {
  id: string;
  name: string;
  vehicle: string;
  status: "Pending" | "Approved" | "Rejected" | "Suspended";
  reason?: string;
};
