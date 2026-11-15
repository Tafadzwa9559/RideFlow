import { api, setAccessToken } from "./client";
import type {
  Credentials,
  Registration,
  TokenResponse,
} from "../../types/auth";
export const authService = {
  signIn: async (email: string, password: string) => {
    const response = await api.post<TokenResponse>("/auth/token/", {
      email,
      password,
    } satisfies Credentials);
    setAccessToken(response.data.access);
    return response;
  },
  signOut: async () => {
    try {
      return await api.post<void>("/auth/logout/");
    } finally {
      setAccessToken(null);
    }
  },
  register: (data: Registration) => api.post("/auth/register/", data),
  forgotPassword: (email: string) =>
    api.post<void>("/auth/password/reset/", { email }),
  resetPassword: (token: string, password: string) =>
    api.post<void>("/auth/password/reset/confirm/", { token, password }),
  verify: (channel: "email" | "phone", code: string) =>
    api.post<void>(`/auth/verify-${channel}/`, { code }),
};
