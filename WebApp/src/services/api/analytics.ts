import { api } from "./client";
import type { AnalyticsSummary } from "../../types/api";
export const analyticsService = {
  summary: (from: string, to: string, signal?: AbortSignal) =>
    api.get<AnalyticsSummary>("/analytics/summary/", {
      params: { from, to },
      signal,
    }),
};
