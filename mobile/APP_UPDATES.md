# Startup update popup — Android and iOS

Both platforms check after the initial app frame and on returning to the
foreground. The app shows an Arabic/English **Update now / Later** dialog with a
direct link to its own store page. It remains usable offline and never forces an
installation. No push notifications or background broadcasts are involved.

## Detection

- Public endpoint: `GET /api/v1/app-updates` (no authentication or user data).
- iOS compares the configured published server release with Apple's public
  Lookup API and uses the newer compatible release. A stale server setting
  cannot hide a newer App Store release; a server policy still works if Apple
  lookup fails. Versions are compared numerically; OS compatibility
  is checked. The fallback uses Saudi Arabia (`APP_STORE_COUNTRY=sa`), the app's
  primary market; configure a different build storefront if needed.
- Android queries Google Play's App Update API. A successful Play answer is
  authoritative for that account/device/rollout. A configured server release
  is a fallback only if Play is unavailable, the installation came from Google
  Play, and Android SDK requirements are satisfied. Debug/sideloaded builds
  cannot use this fallback to imply store-update compatibility.
- Android compares version codes, so a newer build with the same display name
  can prompt. iOS compares public release versions, not TestFlight build numbers.
- All store URLs are canonical and restricted to this app. Server data cannot
  redirect users to an arbitrary website.

Checks are throttled to once every five minutes in the same app process. Every
cold launch can check immediately. “Later” postpones that specific release for
24 hours, including after restarting; a newer release is never hidden by an
older release's reminder. Successfully opening the store does not set the
24-hour reminder. An update arriving while the app is backgrounded waits until
foreground; navigation readiness is retried rather than silently losing it.

## Publish a release

Store checks discover newly available releases automatically when the server
policy is unset. For explicit server control, edit the production backend `.env`
AFTER the release is downloadable in all intended storefronts and its rollout
is complete. Do not set published flags while uploading, waiting for review, or
running a partial rollout. Use the actual version and OS requirements from the
store release:

```dotenv
APP_UPDATE_IOS_PUBLISHED=true
APP_UPDATE_IOS_VERSION=<published iOS version>
APP_UPDATE_IOS_MINIMUM_OS=<minimum iOS version>
APP_UPDATE_ANDROID_PUBLISHED=true
APP_UPDATE_ANDROID_VERSION=<published Android display version>
APP_UPDATE_ANDROID_BUILD=<published Android version code>
APP_UPDATE_ANDROID_MINIMUM_SDK=<minimum Android API level>
```

Then run `php artisan config:cache` and inspect `/api/v1/app-updates`. Missing,
unpublished or invalid policies return null. Set a platform's published flag
false to withdraw its server override; actual native store checks still apply.
No API credentials, database migration or scheduler are needed.

These flags default to false. The deployment of the endpoint does not advertise
a nonexistent release. The next mobile store release must include this code;
previously installed binaries cannot be changed remotely. Users need to install
this implementation once to receive prompts for subsequent releases.

## Validation

- `php artisan test --filter=AppUpdatePolicyTest`
- `flutter test test/app_update_test.dart test/app_update_policy_test.dart test/app_update_startup_test.dart test/widget_test.dart`
- `flutter build apk --profile --no-pub`

Tests cover real app startup on both target platforms, background/resume,
release-specific postponement, store links, numeric versions/builds, invalid
policies, compatibility, concurrent checks, and offline fallback. For final
store eligibility validation, use an older Google Play-installed build with the
matching signing certificate and an eligible newer internal-test release, and
an iPhone with an older public version that already contains this feature. A
sideloaded APK cannot prove Google Play eligibility. Confirm current versions do
not show a popup and Later does not suppress the next release.

Official references:
- https://developer.android.com/guide/playcore/in-app-updates/kotlin-java
- https://developer.android.com/guide/playcore/in-app-updates/test
- https://support.apple.com/102629
