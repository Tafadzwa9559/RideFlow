import { api } from "./client";
import type { Application } from "../../types/user";
import type { Page } from "../../types/api";
export const driversService = {
  list: (signal?: AbortSignal) =>
    api.get<Page<Application>>("/drivers/", { signal }),
  review: (
    id: string,
    data: { status: Application["status"]; reason?: string },
  ) =>
    api.patch<Application>(
      `/drivers/${encodeURIComponent(id)}/verification/`,
      data,
    ),
  availability: (online: boolean) =>
    api.patch<{ online: boolean }>("/drivers/me/availability/", { online }),
  uploadDocument: (kind: string, file: File) => {
    const data = new FormData();
    data.append("kind", kind);
    data.append("file", file);
    return api.post("/drivers/me/documents/", data, {
      headers: { "Content-Type": undefined },
    });
  },
};
