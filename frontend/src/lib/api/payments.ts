import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { Ad } from './ads';

export type PaymentIntent = {
  reference: string;
  redirect_url: string;
  amount: number;
  currency: string;
};

export type InitPaymentResponse = {
  intent: PaymentIntent;
  ad_id: number;
};

/**
 * Open a payment intent against the configured PSP. Returns the redirect
 * URL the wizard's PaymentLauncher should hand off to. With the mock
 * driver the redirect URL points back at our own confirm endpoint.
 */
export async function initAdPayment(adId: number): Promise<InitPaymentResponse> {
  const res = await apiClient.post<InitPaymentResponse>(ENDPOINTS.AD_PAYMENT_INIT(adId), {});
  return res.data!;
}

/**
 * Confirm payment by reference. Returns the freshly-published ad. Idempotent
 * server-side — calling on an already-paid ad returns the same successful
 * payload, so the UI can retry safely.
 */
export async function confirmAdPayment(adId: number, reference?: string): Promise<Ad> {
  const res = await apiClient.post<Ad>(
    ENDPOINTS.AD_PAYMENT_CONFIRM(adId),
    reference ? { ref: reference } : {}
  );
  return res.data!;
}
