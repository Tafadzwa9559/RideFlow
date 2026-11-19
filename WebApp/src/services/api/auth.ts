import { api, setSessionTokens } from "./client";
import type { Registration, StaffTokenResponse } from "../../types/auth";

export const authService = {
  signIn: async (email: string, password: string) => {
    const { data } = await api.post<StaffTokenResponse>("/admin/auth/login/", {
      channel: "email",
      identifier: email.trim(),
      password,
    });
    setSessionTokens(data);
    return data.user;
  },
  signOut: async () => {
    try {
      return await api.post<void>("/auth/logout/");
    } finally {
      setSessionTokens(null);
    }
  },
  register: (data: Registration) => api.post("/auth/register/", data),
  forgotPassword: (email: string) =>
    api.post("/auth/password/request/", { channel: "email", identifier: email }),
  verify: (email: string, code: string) =>
    api.post<{ token: string }>("/auth/password/verify/", {
      channel: "email",
      identifier: email,
      code,
    }),
  resetPassword: (token: string, password: string, confirmation: string) =>
    api.post<void>("/auth/password/reset/", {
      token,
      password,
      password_confirmation: confirmation,
    }),
  changePassword: (current: string, password: string, confirmation: string) =>
    api.post<void>("/auth/password/change/", {
      current_password: current,
      password,
      password_confirmation: confirmation,
    }),
};
