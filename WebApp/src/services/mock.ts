import type { Application, Location, Offer, Trip } from "../types/domain";
export const locations: Location[] = [
  { name: "Avondale Shopping Centre, Harare", lat: -17.7936, lng: 31.0347 },
  { name: "Eastgate Centre, Harare", lat: -17.8316, lng: 31.0529 },
  { name: "Sam Levy’s Village, Borrowdale", lat: -17.7567, lng: 31.0872 },
  { name: "Robert Gabriel Mugabe Airport", lat: -17.9228, lng: 31.0928 },
  { name: "Bulawayo City Hall", lat: -20.15, lng: 28.5833 },
  { name: "Mutare City Centre", lat: -18.9707, lng: 32.6709 },
  { name: "Gweru City Centre", lat: -19.45, lng: 29.8167 },
];
export const categories = [
  {
    name: "Standard",
    description: "Everyday rides, made simple",
    capacity: 4,
    fare: 8.5,
  },
  {
    name: "Comfort",
    description: "A little more room to unwind",
    capacity: 4,
    fare: 11.5,
  },
  { name: "XL", description: "Bring everyone along", capacity: 6, fare: 15 },
];
export const sampleTrips: Trip[] = [
  {
    id: "TR-2041",
    pickup: locations[0],
    destination: locations[1],
    category: "Standard",
    fare: 8.5,
    status: "Ride completed",
    date: "2026-11-12T08:00:00Z",
    payment: "Cash",
    driver: {
      id: "d1",
      name: "Tendai M. (sample)",
      vehicle: "Toyota Corolla · Sample vehicle",
      fare: 8.5,
      verified: true,
    },
  },
  {
    id: "TR-2038",
    pickup: locations[2],
    destination: locations[0],
    category: "Comfort",
    fare: 11.5,
    status: "Ride completed",
    date: "2026-11-10T14:00:00Z",
    payment: "Cash",
  },
  {
    id: "TR-2032",
    pickup: locations[1],
    destination: locations[3],
    category: "Standard",
    fare: 18,
    status: "Ride cancelled",
    date: "2026-11-08T07:00:00Z",
    payment: "Cash",
  },
];
export const sampleApplications: Application[] = [
  {
    id: "D-101",
    name: "Tendai M. (sample)",
    vehicle: "Toyota Corolla · 2019",
    status: "Pending",
  },
  {
    id: "D-102",
    name: "Rudo N. (sample)",
    vehicle: "Honda Fit · 2020",
    status: "Approved",
  },
  {
    id: "D-103",
    name: "Brian C. (sample)",
    vehicle: "Toyota Wish · 2018",
    status: "Pending",
  },
];
const delay = (signal?: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    const timer = setTimeout(resolve, 350);
    signal?.addEventListener(
      "abort",
      () => {
        clearTimeout(timer);
        reject(new DOMException("Aborted", "AbortError"));
      },
      { once: true },
    );
  });
export const mockRides = {
  async list(signal?: AbortSignal) {
    await delay(signal);
    return sampleTrips;
  },
  async offers(fare: number): Promise<Offer[]> {
    await delay();
    return [
      {
        id: "d1",
        name: "Tendai M. (sample)",
        vehicle: "Toyota Corolla · Sample vehicle",
        fare,
        verified: true,
      },
      {
        id: "d2",
        name: "Rudo N. (sample)",
        vehicle: "Honda Fit · Sample vehicle",
        fare: fare + 1.5,
        verified: true,
      },
    ];
  },
};
// A curated schematic fixture, never a road-distance or routing estimate.
export const routeFixture = {
  distance: "6.4 km",
  duration: "18 min",
  points: [
    [-17.7936, 31.0347],
    [-17.8005, 31.0347],
    [-17.8106, 31.044],
    [-17.823, 31.044],
    [-17.8316, 31.0529],
  ] as [number, number][],
};
