import { demoFareRules, cityExamples } from "../config/project";
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type {
  Application,
  Location,
  Notice,
  Role,
  Trip,
  User,
} from "../types/domain";
import { locations, sampleApplications, sampleTrips } from "../services/mock";
type State = {
  user: User | null;
  trips: Trip[];
  activeId: string | null;
  saved: Location[];
  notices: Notice[];
  applications: Application[];
  online: boolean;
  commission: number;
  fareRules: Record<string, number>;
  fareLocation: string;
  setFareConfiguration: (
    rules: Record<string, number>,
    location: string,
    commission: number,
  ) => void;
  login: (role: Role, email?: string) => void;
  logout: () => void;
  updateUser: (data: Partial<User>) => void;
  addTrip: (trip: Trip) => void;
  updateTrip: (id: string, data: Partial<Trip>) => void;
  savePlace: (place: Location) => void;
  removePlace: (name: string) => void;
  readNotice: (id: string) => void;
  notify: (title: string, body: string) => void;
  setOnline: (online: boolean) => void;
  reviewApplication: (
    id: string,
    status: Application["status"],
    reason?: string,
  ) => void;
  setCommission: (value: number) => void;
};
export const useAppStore = create<State>()(
  persist(
    (set) => ({
      user: null,
      trips: sampleTrips,
      activeId: null,
      saved: [locations[0], locations[2]],
      applications: sampleApplications,
      online: false,
      commission: 15,
      fareRules: { ...demoFareRules },
      fareLocation: cityExamples[0],
      setFareConfiguration: (fareRules, fareLocation, commission) =>
        set({ fareRules, fareLocation, commission }),
      notices: [
        {
          id: "welcome",
          title: "Welcome to the Trivia preview",
          body: "All trips, offers and account actions in this workspace are demonstrations.",
          read: false,
        },
      ],
      login: (role, email) =>
        set({
          user: {
            id: `demo-${role}`,
            firstName:
              role === "admin"
                ? "Alex"
                : role === "driver"
                  ? "Tendai"
                  : "Tariro",
            lastName: "Demo",
            email: email || `${role}@trivia.test`,
            phone: "",
            role,
          },
        }),
      logout: () => set({ user: null, online: false }),
      updateUser: (data) =>
        set((s) => ({ user: s.user ? { ...s.user, ...data } : null })),
      addTrip: (trip) =>
        set((s) => ({ trips: [trip, ...s.trips], activeId: trip.id })),
      updateTrip: (id, data) =>
        set((s) => ({
          trips: s.trips.map((t) => (t.id === id ? { ...t, ...data } : t)),
        })),
      savePlace: (place) =>
        set((s) => ({
          saved: s.saved.some((p) => p.name === place.name)
            ? s.saved
            : [...s.saved, place],
        })),
      removePlace: (name) =>
        set((s) => ({ saved: s.saved.filter((p) => p.name !== name) })),
      readNotice: (id) =>
        set((s) => ({
          notices: s.notices.map((n) =>
            n.id === id ? { ...n, read: true } : n,
          ),
        })),
      notify: (title, body) =>
        set((s) => ({
          notices: [
            { id: crypto.randomUUID(), title, body, read: false },
            ...s.notices,
          ],
        })),
      setOnline: (online) => set({ online }),
      reviewApplication: (id, status, reason) =>
        set((s) => ({
          applications: s.applications.map((a) =>
            a.id === id ? { ...a, status, reason } : a,
          ),
        })),
      setCommission: (commission) => set({ commission }),
    }),
    {
      name: "trivia-demo-v1",
      partialize: (s) => ({
        user: s.user,
        trips: s.trips,
        activeId: s.activeId,
        saved: s.saved,
        notices: s.notices,
        applications: s.applications,
        commission: s.commission,
        fareRules: s.fareRules,
        fareLocation: s.fareLocation,
      }),
    },
  ),
);
