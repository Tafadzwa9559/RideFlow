import { api } from "./client";
import type { Page, Payment } from "../../types/api";
export const paymentsService = {
  list: (signal?: AbortSignal) =>
    api.get<Page<Payment>>("/payments/", { signal }),
  hostedCheckout: (id: string) =>
    api.post<{ checkout_url: string }>(
      `/payments/${encodeURIComponent(id)}/checkout/`,
    ),
  requestRefund: (id: string, reason: string) =>
    api.post<void>(`/payments/${encodeURIComponent(id)}/refund/`, { reason }),
};
