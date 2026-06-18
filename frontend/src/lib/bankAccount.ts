/**
 * Static bank-transfer details shown on the publish-fee Pay step while the
 * payment-gateway (Moyasar) integration is not yet live. Sellers transfer the
 * fee to this account and upload a receipt for admin review.
 *
 * The QR image (public/bank-account.jpeg) already encodes these same details
 * for in-app banking scan-to-pay.
 */
export const BANK_ACCOUNT = {
  bankName: 'مصرف الراجحي',
  accountName: 'مؤسسة برق واضح',
  accountNumber: '433000010006086240365',
  iban: 'SA9080000433608016240365',
  qrImage: '/bank-account.jpeg',
} as const;
