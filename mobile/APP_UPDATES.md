# Android and iPhone update prompts

The iOS app checks Apple's public Lookup API after the first frame and when
returning to the foreground. It reads the installed version from the iOS bundle,
compares numeric release versions (not build numbers), and opens the verified
`apps.apple.com` listing when the user chooses Update now.

- Checks are limited to once per hour in a running app.
- Closing the prompt postpones reminders for 24 hours, including after restart.
- Offline, timeout, missing listing and malformed responses silently skip the check.
- Releases requiring a newer iOS version are skipped.
- The lookup uses the Saudi storefront, the app's primary market. Override with
  `--dart-define=APP_STORE_COUNTRY=xx` for a different distribution market. This
  is a build setting, not detection of the user's Apple account storefront.
- Arabic/English and the existing light/dark theme are supported.

Publish a new iOS release containing this code using the normal App Store release
process. Users must install that release once before receiving prompts for later
releases. Subsequent releases need no backend version change: the check uses the
public listing after Apple makes the release available there. TestFlight builds
and uploads still awaiting release do not constitute a public update.

This feature is an optional in-app prompt on Android and iOS, not a background
push broadcast. It does not force installation or reinstall
the app. No new Flutter dependencies are required.

Validation: `flutter test test/app_update_test.dart test/widget_test.dart`.
Device smoke test before publication: on an iPhone running an older public
version containing this feature, verify prompt, Later/relaunch suppression,
Update now → App Store, and offline launch. A current or newer installed version
must not prompt.


## Android

Android now participates in the same startup/foreground checks and reminder
schedule. Its native `installedInfo` channel queries the Google Play App Update
API (app-update 2.1.0). The app shows a prompt only when Play reports an update
available for this device/account and the available version code exceeds the
installed code. This respects Play rollout eligibility rather than scraping a
public listing. “Update now” opens this app's Google Play listing; this is not an
embedded flexible download/install flow. No automatic or forced installation.

Google Play returns a build number, not the human-readable release version, so
the Android dialog says “A new version is available” rather than showing a build
number as a version. Failure, unavailable Play services, and sideloaded APKs skip
the prompt safely. Native checks time out after 10 seconds in Flutter.

## Releasing and reaching existing users

Uploading a build is not the same as publishing it. Wait for store approval and
actual release availability before expecting a prompt. Increase Android's
version code with every release; increase iOS's public version for each new App
Store release. The current local version is 1.0.3+15; rebuilding this exact version
does not create a newer public iOS update.

Users on an older Android version without this feature must update once before
it can detect later releases. The same applies to iOS versions predating its
lookup-based prompt. You cannot remotely add this logic to already installed
binaries. A separate release-announcement push could reach existing users who
have registered push tokens and granted notification permission; it is not sent
or automated by this feature and cannot guarantee delivery to every user.

Android end-to-end validation requires a Play-installed/owned app with the same
application ID and signing certificate as an eligible newer release. Test using
Google Play internal testing/internal app sharing as documented by Google.
A sideloaded debug/profile APK cannot validate production update eligibility.

Sources:
- https://developer.android.com/guide/playcore/in-app-updates/kotlin-java
- https://developer.android.com/guide/playcore/in-app-updates/test
- https://support.apple.com/102629
