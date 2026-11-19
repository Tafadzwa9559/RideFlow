import { create } from "zustand";
import { env } from "../config/env";
import { api, setAccessToken } from "../services/api/client";
import { authService } from "../services/api/auth";
import { useAppStore } from "./useAppStore";
import type { User } from "../types/user";
type Session = {
  user: User | null;
  initialized: boolean;
  demo: boolean;
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  loginDemo: () => void;
  logout: () => Promise<void>;
  clearSession: () => void;
};
let initialization: Promise<void> | undefined;
export const useAuthStore = create<Session>((set) => ({
  user: null,
  initialized: false,
  demo: false,
  initialize: () =>
    (initialization ??= (async () => {
      if (!env.apiBaseUrl) {
        set({ initialized: true });
        return;
      }
      try {
        const { data } = await api.get<User>("/users/me/", {
          withCredentials: true,
        });
        if (data.role === "admin") {
          set({ user: data });
          useAppStore.setState({ user: data });
        }
      } catch {
        setAccessToken(null);
      } finally {
        set({ initialized: true });
      }
    })()),
  login: async (email, password) => {
    if (!env.apiBaseUrl)
      throw new Error(
        "Admin authentication is not configured. Contact your platform administrator.",
      );
    const profile = await authService.signIn(email, password);
    const user: User = {
      id: profile.id,
      firstName: profile.first_name,
      lastName: profile.last_name,
      email: profile.email,
      phone: profile.phone,
      role: "admin",
    };
    set({ user, demo: false, initialized: true });
    useAppStore.setState({ user });
  },
  loginDemo: () => {
    if (!env.adminDemo) return;
    const user: User = {
      id: "demo-admin",
      role: "admin",
      firstName: "Admin",
      lastName: "Preview",
      email: "admin@trivia.test",
      phone: "",
    };
    set({ user, demo: true, initialized: true });
    useAppStore.setState({ user });
  },
  clearSession: () => {
    setAccessToken(null);
    set({ user: null, demo: false });
    useAppStore.getState().logout();
  },
  logout: async () => {
    const wasDemo = useAuthStore.getState().demo;
    try {
      if (!wasDemo && env.apiBaseUrl) await authService.signOut();
    } finally {
      useAuthStore.getState().clearSession();
    }
  },
}));
