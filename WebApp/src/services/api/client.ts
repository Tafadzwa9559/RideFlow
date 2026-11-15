import axios from "axios";
import { env } from "../../config/env";
import type { TokenResponse } from "../../types/auth";
// Production adapters are opt-in and are never invoked by the demo UI.
export const api = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: 15000,
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});
let accessToken: string | null = null;
let refreshFlight: Promise<string> | null = null;
export function setAccessToken(token: string | null) {
  accessToken = token;
}
api.interceptors.request.use((config) => {
  if (!env.apiBaseUrl)
    throw new Error(
      "Configure VITE_API_BASE_URL before using live API adapters.",
    );
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`;
  return config;
});
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config;
    if (error.response?.status === 401 && config && !config._retry) {
      config._retry = true;
      try {
        refreshFlight ??= axios
          .post<TokenResponse>(
            `${env.apiBaseUrl}/auth/token/refresh/`,
            {},
            { withCredentials: true },
          )
          .then((r) => {
            setAccessToken(r.data.access);
            return r.data.access;
          })
          .finally(() => {
            refreshFlight = null;
          });
        await refreshFlight;
        return api(config);
      } catch {
        setAccessToken(null);
      }
    }
    return Promise.reject(
      new Error(
        error.response?.data?.detail ||
          (error.code === "ERR_CANCELED"
            ? "Request cancelled"
            : "Unable to complete the request. Please try again."),
      ),
    );
  },
);
