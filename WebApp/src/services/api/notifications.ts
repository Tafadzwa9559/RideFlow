import { api } from "./client";
import type { Notice } from "../../types/domain";
import type { Page } from "../../types/api";
export const notificationsService = {
  list: (signal?: AbortSignal) =>
    api.get<Page<Notice>>("/notifications/", { signal }),
  markRead: (id: string) =>
    api.patch<Notice>(`/notifications/${encodeURIComponent(id)}/`, {
      read: true,
    }),
  markAllRead: () => api.post<void>("/notifications/read-all/"),
};
