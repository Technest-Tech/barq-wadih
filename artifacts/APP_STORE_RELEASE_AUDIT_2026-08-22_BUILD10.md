# Barq Wadih — App Store release audit, Build 10

Date: 22 August 2026
Version audited and built: **1.0.1 (10)** · Bundle ID `com.barqwadih.app` · Team `Y4LJJQ2DGA`

---

## 1. Outcome in one paragraph

The previous rejection reason (Guideline 5.1.1(v), phone number required) is fixed and verified
against the production API — an account can be created and fully used with an email address alone.
Two **separate, previously undetected P0 defects** were found and fixed: in-app account deletion was
**completely broken in production** for any account that had chats, and the Firebase Auth identity
survived deletion for every email-only account. Both are Apple account-deletion requirements. Both
are now fixed, deployed, and verified end-to-end against production. Two further production bugs
(FCM stale-token cleanup, web chat re-seed denied by Firestore rules) were found and fixed.

**This build is not submitted.** Upload and App Store Connect metadata both require the account
holder — see §8.

---

## 2. Critical findings

### P0-1 — In-app account deletion failed in production (Guideline 5.1.1(v))

`AuthService::deleteAccount()` calls `FirestoreChatDataEraser::eraseForUser()` before touching SQL,
by design, so the API can never report success while chat data survives. That eraser threw on every
production request:

1. **Credentials never loaded over HTTP.** `FIREBASE_CREDENTIALS` is the project-relative path
   `storage/firebase-service-account.json`. `is_file()` resolves it under `php artisan` (cwd =
   project root) but **not** under PHP-FPM, whose cwd is `public/`. The eraser therefore threw
   `Firebase service credentials are invalid.` and deletion returned HTTP 500. It passed from the
   CLI and in CI, which is why it was never caught.
2. **The Storage bucket does not exist.** Firebase Storage was never provisioned on
   `barqwadih-40271` (both `…firebasestorage.app` and `…appspot.com` return 404). The chat-media
   cleanup called `->throw()` on that 404 and aborted the whole deletion.

Both fixed in `backend/app/Services/FirestoreChatDataEraser.php`. Relative credential paths now
resolve against `base_path()`; a missing bucket is treated as "nothing to erase" (accurate — the
mobile app stores chat media on this server, not in Firebase Storage), while **every other failure
still aborts the deletion**.

Verified in production with a disposable account that had a conversation and messages:
HTTP 200, Firestore conversations `1 → 0`, messages `2 → 0`, SQL row anonymised and soft-deleted,
Sanctum token revoked (`/auth/me` → 401).

### P0-2 — The Firebase Auth identity outlived the deleted account

Chat always signs in to Firebase as `strval($user->id)` (`ChatService::mintCustomToken`), never as
`firebase_uid` — which only the legacy phone-OTP path ever sets. Deletion only removed
`firebase_uid`, so **every email-only account left a live Firebase identity behind**, whose refresh
token would keep working.

Fixed in `backend/app/Services/AuthService.php`: both identities are now revoked.

Verified in production: created a disposable account, signed in with a real custom token
(Firebase user `45` confirmed present), deleted the account →
Firebase user **NOT_FOUND**, and the stale refresh token is rejected with `USER_NOT_FOUND`.

### P1-1 — Posting a listing still required a phone number

`post_ad_screen.dart` defaulted `_showPhonePublicly = true`, and the backend rule is
`contact_phone → required_if:show_phone_publicly,1`. An email-only account therefore could not get
past step 2 of posting a listing without entering a phone number — the same pattern Apple rejected
under 5.1.1(v), one screen further in.

Fixed: the toggle now defaults **off**, the field is labelled `رقم التواصل (اختياري)` while it is
off, and a helper line explains buyers reach the seller through in-app chat. Edit mode still
restores whatever the seller originally chose.

### P1-2 — Chat schema mismatch between mobile and web

Mobile wrote/read `peerNames` / `peerAvatars`; web wrote/read `participantNames` /
`participantAvatars`. Threads started on one platform showed the ad title instead of the person's
name on the other. Both clients now write both spellings and read either. 5 regression tests added.

### P1-3 — Repeated web conversation seeding was denied by the Firestore rules

Found with the Firebase emulator, not by reading. `startConversation()` always passes a seed, and
`setDoc(merge:true)` re-stamps `createdAt` with a fresh `serverTimestamp()`. `createdAt` was not in
the update rule's allowed key list, so **the second time a buyer messaged the same seller about the
same ad from the web, the write was denied and the message silently failed**. `createdAt` added to
the allowed update keys; 26/26 rules tests pass.

### P1-4 — FCM stale-token cleanup crashed every push batch

`PushService` called `SendReport::index()`, which does not exist in kreait 7. Production logged
`fcm.dispatch_failed` on every push with failures, and any batch after the first was never sent.
Replaced with the report's own `invalidTokens()` / `unknownTokens()` — which also stops a transient
send error from deactivating a healthy device.

Verified on production by dispatching to one deliberately unregistered token (no real device was
targeted): the call completed without throwing, no new `fcm.dispatch_failed` line was logged
(13 → 13), and the active-device count was unchanged (15 → 15), proving the new code neither crashes
nor over-deactivates.

### P2 — Quality

- Removed the dead `BoostConfirmSheet` (unreachable, advertised "free during the trial period") and
  the unused `boostAd` / `getBoostConfig` API methods. Verified absent from the shipped binary.
- Removed "electronic payment gateways are being prepared" from two screens.
- Report sheet showed a raw `DioException` dump on failure (e.g. a duplicate report, HTTP 409);
  it now shows the API's Arabic message, and an Arabic sign-in prompt on 401.
- Denying the microphone made the voice-record button silently do nothing; it now explains why.
- Removed `NSLocationAlwaysAndWhenInUseUsageDescription`. geolocator only takes the "Always" branch
  when the When-In-Use key is absent, so the app never requested it and there is no `location`
  background mode — the key was unused and its own text said background location is not used.

---

## 3. Files changed

**Mobile (in the shipped binary)**
- `lib/features/ads/presentation/screens/post_ad_screen.dart` — phone opt-in
- `lib/features/messages/data/chat_repository.dart` — write both chat schemas
- `lib/features/messages/domain/chat_models.dart` — read either schema (+ merge helpers)
- `lib/features/messages/presentation/screens/conversation_screen.dart` — read either schema; mic denial message
- `lib/features/reports/presentation/report_sheet.dart` — surface API error messages
- `lib/features/ads/data/ad_api.dart` — removed dead boost endpoints
- `lib/features/ads/presentation/widgets/boost_confirm_sheet.dart` — **deleted**
- `lib/features/ads/presentation/screens/bank_transfer_screen.dart` — payment copy
- `lib/features/settings/presentation/screens/payments_screen.dart` — payment copy
- `ios/Runner/Info.plist` — removed the unused Always-location key
- `test/chat_schema_compat_test.dart` — **new**, 5 tests
- `test/report_sheet_layout_test.dart` — **new**, 17 tests

**Backend**
- `app/Services/FirestoreChatDataEraser.php` — P0-1
- `app/Services/AuthService.php` — P0-2
- `app/Services/PushService.php` — P1-4
- `app/Console/Commands/SeedDemoChats.php` — seeds both chat schemas (not deployed, not re-run)
- `tests/Feature/FirestoreChatDataEraserTest.php` — **new**, 6 tests
- `tests/Feature/AccountDeletionFirebaseIdentityTest.php` — **new**, 2 tests
- `tests/Feature/PushServiceTokenCleanupTest.php` — **new**, 1 test

**Firebase**
- `firestore.rules` — P1-3

**Frontend — changed but NOT deployed (see §8)**
- `src/lib/firebase/chatWrites.ts`, `src/lib/api/chat.ts`,
  `src/components/messages/ConversationList.tsx`,
  `src/app/[locale]/messages/[conversationId]/page.tsx` — chat schema
- `src/components/layout/Header/Header.tsx` — dropped the banned real-estate category from the search placeholder
- `src/app/[locale]/admin/categories/page.tsx`, `src/app/[locale]/admin/pages/page.tsx` — stale fee copy
- `src/app/[locale]/post-ad/_components/pay/PaymentLauncher.tsx` — **deleted** (unreachable Apple Pay / Mada UI)

Only intentionally changed files were formatted (`dart format`, `pint`, and `SeedDemoChats.php` left
in its own alignment style deliberately). Nothing was committed, pushed, or merged.

---

## 4. Production changes

| Change | Status | Backup |
|---|---|---|
| Migration `2026_08_22_000001_align_legal_pages_with_app_store_review` | Applied, batch 16 | `storage/app/backups/static_pages-pre-legal-migration.json` (8 rows) |
| `FirestoreChatDataEraser.php` | Deployed | `…/FirestoreChatDataEraser.php.pre-bucket-fix` |
| `AuthService.php` | Deployed | `…/AuthService.php.pre-firebase-identity-fix` |
| `PushService.php` | Deployed | `…/PushService.php.pre-fcm-fix` |

After each deploy: config/route/view caches rebuilt, PHP-FPM reloaded, queue workers restarted
(`queue:restart`) for the PushService change. Health `200` throughout; **no production errors since
the fixes**, including three successful account deletions.

Live legal content verified: fees page lists bank transfer only (no card brands), delete-account
page now says chats and their media are erased, privacy policy covers all 16 required disclosure
topics.

Live commission values confirmed: cars **99 SAR**, other paid categories **10 SAR**, jobs **free** —
matching every fee screen in the app. Publishing is free everywhere.

**Testing was done with disposable accounts only.** Three were created and deleted; zero residue
(0 ads, reports, ratings, devices, search logs; 0 live QA users). No real user, conversation, ad,
report or payment was touched.

---

## 5. Firebase

- **Firestore rules deployed** to `barqwadih-40271`; the deployed file is byte-identical to the one
  that passed 26/26 emulator tests.
- **Indexes**: the two required composite indexes are already live; nothing deployed, so no index
  could be dropped.
- **Storage rules could NOT be deployed** — Firebase Storage has never been provisioned on the
  project. This does not affect the iOS app, which uploads chat media to Laravel
  (`POST /chat/conversations/{id}/media`) and does not link the Firebase Storage SDK at all. It does
  mean **web** chat image/voice upload is broken — a pre-existing web bug, not an App Store issue.

---

## 6. Verification

| Suite | Result |
|---|---|
| Backend `php artisan test` | **39 passed, 124 assertions** (was 30/110) |
| Flutter `flutter test` | **27 passed** (was 5) |
| `flutter analyze` | **No issues found** |
| Firestore rules (emulator) | **26/26** |
| Frontend `tsc --noEmit` | clean |
| Frontend `eslint` (changed files) | 0 errors (pre-existing warnings only) |

**Verified against the live production API** (disposable accounts): registration with email only and
no phone; login; `/auth/me` returning `phone: null`; Firebase custom token issued with `uid = user
id`; account deletion incl. Firestore erasure, Firebase Auth revocation, and refresh-token rejection.

**Simulators** — app installed and launched, live production data, correct RTL, correct safe areas,
no debug banner, no overflow:
- iPad Air 11-inch (M3) — Apple's review device, iPhone compatibility mode
- iPhone 16e (small)
- iPhone 17 Pro Max (6.9-inch)

The report sheet is additionally covered by 17 deterministic layout tests at those exact device
metrics, in portrait **and** landscape, with the keyboard raised and at 1.6× Dynamic Type — send
button reachable in every case.

UI tap-through could not be automated: macOS Accessibility permission is not granted to `osascript`,
and the project has no `integration_test` dependency.

**The paired iPhone was deliberately not used.** `Ahmed's iPhone` (iPhone 16 Pro Max, iOS 26.6,
UDID `00008140-…801C`) is paired and *is* covered by the development profile, whose certificate
matches an installed identity — so a device build is possible. It was skipped because the Debug
configuration uses **Automatic** signing, which needs the Xcode account that is missing (§8), and
forcing it would have meant editing the release signing configuration hours before submission. The
substituting evidence is stronger than a launch screenshot would have been: the same code is already
running on real hardware in production (15 active APNs device registrations, 101 live listings, 236
ratings), and the shipped binary was verified directly. Once signed in for the upload, the owner can
run it on the device from Xcode in one click.

**Every fix was verified inside the shipped binary**, matching Arabic strings in the Dart snapshot's
UTF-16 string table against a known-unchanged positive control: all 8 new/changed strings present,
all 4 removed strings absent.

---

## 7. Build

- IPA: `mobile/build/ios/ipa/barq_wadih.ipa` — 63,196,298 bytes
- SHA-256 `3e0a978bdc0498ea607db4fe7dc671e820cd0dd89e7eac75f191b42d774facf9`
- Archive: `mobile/build/ios/archive/Runner.xcarchive` (508.6 MB) — ready to upload from Organizer
- CFBundleIdentifier `com.barqwadih.app` · CFBundleShortVersionString `1.0.1` · CFBundleVersion `10`
- MinimumOSVersion `15.0` · arm64 · release, no debug entitlements
- Signed **Apple Distribution: Saleh Al anazi (Y4LJJQ2DGA)**, profile "Barq Wadih App Store" (expires 2027-08-12)
- `aps-environment = production`, `get-task-allow = false`
- Built with **Xcode 26.3 / iOS 26.2 SDK** — meets the 28 April 2026 minimum-SDK requirement
- `ITSAppUsesNonExemptEncryption = false` — correct: HTTPS/TLS and Keychain only, no custom crypto
- Purpose strings: Camera, Face ID, Location When In Use, Microphone, Photo Library — all match real behaviour
- **No app-level privacy manifest, and none is required.** Apple's rule is that you declare only what
  your own code calls; SDKs ship their own. First-party Dart and Swift use no required-reason APIs
  (no file-timestamp, disk-space, UserDefaults or active-keyboard calls). 31 privacy manifests are
  bundled; the 6 frameworks without one are `App.framework` (the app's own Dart code, covered above),
  four header-only Firebase/Recaptcha interop shims, and `audioplayers_darwin`. Build 9 shipped the
  same pod set and passed upload validation without ITMS-91053.
- **No tracking**: no AdSupport, no AppTrackingTransparency, no IDFA symbols, no advertising or
  analytics pods, no `NSUserTrackingUsageDescription`.

---

## 8. Blockers that require the account holder

1. **Upload.** Xcode has **zero** signed-in Apple IDs
   (`DVTDeveloperAccountManagerAppleIDLists` is an empty list) — this is the real cause of
   `exportArchive Failed to Use Accounts`. Transporter is not installed. The only key on this
   machine is `~/.private_keys/AuthKey_HF93K8B8XF.p8`, with **no Issuer ID recorded anywhere** and
   every indication it is the APNs key, which must not be used as an App Store Connect API key.
   → Sign in at Xcode → Settings → Accounts with the Account Holder Apple ID and complete 2FA, then
   upload the existing archive from Organizer. No rebuild is needed.
2. **App Store Connect metadata.** No browser automation is available in this session, so nothing in
   ASC was read or changed. See the checklist below.
3. **Demo account password.** `appreview@barqwadih.com` (id 34) exists, is active, has **no phone**,
   and has 2 seeded conversations so Report/Block are reachable — but its password must come from
   the password manager. It was neither read nor reset.
4. **Moderation SLA.** The block/report sheet promises review "within 24 hours". Keep it only if
   that is genuinely met; the ad report sheet uses neutral wording.

---

## 9. App Store Connect checklist

- [ ] Remove **عقارات** from keywords — real estate was removed by migration, is filtered client-side,
      and is explicitly banned in the app's Terms. Advertising it risks a metadata rejection.
- [ ] Support URL = `https://barqwadih.com/ar/contact` (200). **`/support` returns 404.**
- [ ] Privacy Policy URL = `https://barqwadih.com/ar/privacy` (200)
- [ ] Account Deletion URL = `https://barqwadih.com/ar/delete-account` (200)
- [ ] App Privacy: **remove Advertising Data and Third-Party Advertising**; set "Data Not Used to
      Track You". Verified from source, pods, and the compiled binary.
- [ ] App Privacy: declare Name, Email, optional Phone, User ID, Device ID (FCM token), Precise and
      Coarse Location, Photos/Video, Audio, other User Content, Search History, Product Interaction,
      Customer Support, and commission payment records — all linked, none used for tracking.
- [ ] Age rating: answer yes to user-generated content and to messaging/chat.
- [ ] Review Notes: replace the Build 9 text with Build 10 text.
- [ ] Sign-In Information: `appreview@barqwadih.com` + password from the password manager.
- [ ] Review contact name / phone / email populated.
- [ ] Screenshots reflect the current app; no real estate, no boost/upgrade, no card payment.
- [ ] **The two demo videos in `artifacts/` are from 15 August** and predate the phone-opt-in change.
      Re-record or detach them if they are attached to the submission.
- [ ] Select build **1.0.1 (10)** once processing finishes; check the processing email for warnings.
- [ ] Confirm the automatic-vs-manual release setting.
- [ ] Confirm trademark ownership evidence for "برق واضح" vs the developer name (Guideline 5.2.1).

### Suggested Review Notes

> Build 10 addresses the previous App Review feedback under Guideline 5.1.1(v). A phone number is
> optional everywhere: reviewers can create and fully use an account with only a name, email address
> and password, including posting a listing. Browsing, search and listing details are available
> without any account. This build also includes in-app account deletion (Profile → «حذف الحساب
> والبيانات نهائيًا», type «حذف» to confirm), which erases sign-in data, the public profile,
> listings and their images, and all conversations and chat media. Listings and users can be
> reported, and users can be blocked, from the listing page, the seller profile and inside a
> conversation. Publishing a listing is free; any bank transfer relates only to a fixed after-sale
> commission on a completed sale of a physical good or service, never to a digital feature. A working
> demo account is provided in the Sign-In Information fields; its Messages tab is pre-populated so the
> Report and Block controls are reachable immediately.

---

## 10. Status

**Not "no known remaining App Store rejection blockers".** The engineering work is done and verified,
but four items remain open and all four need the account holder: the build is not uploaded, ASC
metadata is unaudited and still carries a keyword the app cannot honour, the demo password is
unverified, and the App Privacy advertising declarations still need correcting. Once §8 and §9 are
complete, this build has no known remaining rejection blockers from the code, backend, Firebase or
binary side.

Nobody can guarantee approval — App Review is a human process.
