# TikTok and Snapchat app tracking

The mobile app sends audited business events to two destinations:

- TikTok App Events SDK runs natively on Android and iOS.
- Snapchat Conversions API is called by the Laravel backend. The mobile app
  never receives the Snapchat access token.

Tracking is best-effort. A TikTok or Snapchat outage must not block login,
registration, search, contact actions, favorites, or publishing an ad.

## Event map

| App action | TikTok event | Snapchat event |
| --- | --- | --- |
| App opened | `LaunchAPP` (automatic) | `APP_OPEN` |
| First install | `InstallApp` (automatic) | `APP_INSTALL` (once) |
| Registration completed | `Registration` | `SIGN_UP` |
| Login completed | `Login` | `LOGIN` |
| Ad details viewed | `ViewContent` | `VIEW_CONTENT` |
| Search submitted | `Search` | `SEARCH` |
| Ad added to favorites | `AddToWishlist` | `ADD_TO_WISHLIST` |
| Seller contacted | `GenerateLead` | `CUSTOM_EVENT_2` |
| New ad published | `PublishAd` | `CUSTOM_EVENT_1` |

## Local configuration

Real credentials are intentionally stored in ignored local files:

- Android: `mobile/android/tracking.properties`
- iOS: `mobile/ios/Flutter/Tracking.xcconfig`
- Snapchat server token: `backend/.env`

When configuring a new machine, copy the same keys from those files. The
tracked `.env.example` contains the Snapchat variable names but no secret.

For production, set these backend environment variables before clearing the
Laravel configuration cache:

```dotenv
SNAPCHAT_APP_ID=
SNAPCHAT_CAPI_TOKEN=
SNAPCHAT_CAPI_ENDPOINT=https://tr.snapchat.com/v3
SNAPCHAT_EVENT_SOURCE_URL=https://barqwadih.com/app
```

Then run:

```bash
php artisan config:clear
```

## Release verification

1. Build and install a fresh Android and iOS release on real devices.
2. On iOS, answer the App Tracking Transparency prompt in both states during
   separate tests. Denied users must remain anonymous.
3. Complete each action in the event map once with a test account.
4. Confirm receipt and diagnostics in TikTok Events Manager and Snapchat
   Events Manager. Dashboard appearance can be delayed.
5. Confirm Laravel logs do not contain repeated `Snapchat CAPI rejected event`
   or `Snapchat CAPI request failed` entries.

Do not add payment or purchase events until the backend has a confirmed,
authoritative payment state. The SDK automatic payment event collection is
disabled for that reason.
