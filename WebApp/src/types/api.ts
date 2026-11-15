export interface Page<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}
export interface Vehicle {
  id: string;
  driver: string;
  make: string;
  model: string;
  year: number;
  registration: string;
  capacity: number;
}
export interface Payment {
  id: string;
  ride: string;
  amount: string;
  currency: string;
  method: string;
  status: "pending" | "completed" | "failed" | "refunded";
}
export interface AnalyticsSummary {
  rides: number;
  passengers: number;
  drivers: number;
  revenue: string;
  series: { date: string; rides: number; revenue: string }[];
}
