# Barq Wadih (برق واضح) — Project Overview

## 1. Project Identity

| Field | Value |
|---|---|
| **Project Name** | Barq Wadih (برق واضح) |
| **Type** | Classifieds & Marketplace Platform |
| **Philosophy** | "Trusted Commercial Community" — ethical trade powered by reputation, honor-based commissions, and community accountability |
| **Target Market** | Saudi Arabia (KSA) |
| **Primary Language** | Arabic (RTL-first), English secondary |
| **Reference App** | Haraj (حراج) |
| **Platforms** | Mobile (iOS + Android), Web, Admin Panel |

---

## 2. Technology Stack

### Backend — Laravel
| Component | Technology |
|---|---|
| **Framework** | Laravel 11+ (PHP 8.3) |
| **API Style** | RESTful JSON API |
| **Authentication** | Laravel Sanctum (token-based for mobile + SPA) |
| **Search** | Meilisearch + Laravel Scout |
| **Queue / Jobs** | Laravel Queue (Redis driver) |
| **File Storage** | DigitalOcean Spaces (S3-compatible) |
| **Caching** | Redis |
| **Scheduler** | Laravel Task Scheduling (ad expiry, banner cron) |
| **Payment Gateway** | Tap / Moyasar (SAR-native, SADAD + mada + Visa/MC) |

### Frontend — Next.js (Web + Admin)
| Component | Technology |
|---|---|
| **Framework** | Next.js 14+ (App Router) |
| **Language** | TypeScript |
| **Styling** | Vanilla CSS (design system tokens) |
| **i18n** | next-intl (Arabic-first, RTL) |
| **State Management** | React Context + SWR / TanStack Query |
| **Admin Panel** | Integrated route group within Next.js (`/admin/*`) |

### Mobile — Flutter
| Component | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **State Management** | Riverpod or BLoC |
| **HTTP Client** | Dio |
| **Auth** | Firebase Auth (Phone OTP) + Laravel Sanctum tokens |
| **Chat** | Firebase Firestore (real-time) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Image Handling** | cached_network_image + image_picker |
| **Search** | Calls Meilisearch via Laravel API |

### Infrastructure — DigitalOcean
| Component | Technology |
|---|---|
| **Server** | DigitalOcean Droplet (16GB RAM) |
| **Object Storage** | DigitalOcean Spaces (images, media) |
| **Database** | Managed MySQL 8 (or self-hosted on Droplet) |
| **CDN** | DigitalOcean Spaces CDN (built-in) |
| **SSL** | Let's Encrypt (auto-renew via Certbot / Nginx) |
| **Search Engine** | Meilisearch (self-hosted on Droplet) |
| **Cache/Queue** | Redis (self-hosted on Droplet) |
| **CI/CD** | GitHub Actions → deploy to Droplet via SSH |
| **Monitoring** | Laravel Telescope (dev) + basic uptime monitoring |

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        DigitalOcean Droplet (16GB)               │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │   Nginx     │  │  Laravel API │  │  Meilisearch           │  │
│  │  (Reverse   │──│  (PHP-FPM)   │──│  (Full-text search)    │  │
│  │   Proxy)    │  │              │  │                        │  │
│  └─────────────┘  └──────────────┘  └────────────────────────┘  │
│                          │                                       │
│                   ┌──────┴──────┐                                │
│                   │    Redis    │                                │
│                   │ Cache+Queue │                                │
│                   └─────────────┘                                │
│                          │                                       │
│                   ┌──────┴──────┐                                │
│                   │   MySQL 8   │                                │
│                   └─────────────┘                                │
└──────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐
│  Next.js    │     │  Flutter    │     │    Firebase       │
│  (Web +     │     │  (iOS +     │     │  • Auth (OTP)     │
│   Admin)    │     │   Android)  │     │  • Firestore Chat │
│             │     │             │     │  • FCM Push       │
└─────────────┘     └─────────────┘     └──────────────────┘
                                                │
                                        ┌───────┴───────┐
                                        │  DO Spaces    │
                                        │  (Images/CDN) │
                                        └───────────────┘
```

### Key Architectural Decisions

1. **Firebase for Chat & Auth OTP** — Chat messages stored in Firestore (real-time, no WebSocket server needed). Phone OTP handled by Firebase Auth. Laravel Sanctum handles API token auth after Firebase verifies the phone number.

2. **Meilisearch for Search** — Self-hosted on the Droplet. Arabic typo-tolerance, instant results, low RAM footprint (~200MB). Synced via Laravel Scout model observers.

3. **Commission = Honor-Based Trigger + Digital Payment** — The platform does NOT process peer-to-peer transactions. Seller self-declares a sale completion, then pays 0.5% commission (or 90 SAR flat for dealerships) via integrated payment gateway (Tap/Moyasar).

4. **Post-Publish Moderation** — Ads go live immediately. Flagged/reported ads enter a review queue in the admin panel. Prohibited content (cats/dogs in Animals category) is caught via manual review + keyword filters.

5. **Single Next.js App for Web + Admin** — Admin panel lives under `/admin/*` route group with separate layout, middleware, and RBAC. No separate admin deployment needed.

---

## 4. Platform Categories

| # | Category (Arabic) | Category (English) | Notes |
|---|---|---|---|
| 1 | سيارات | Cars | Requires: type, model, mileage, price |
| 2 | تشليح سيارات | Car Scrap/Salvage | Spare parts, damaged cars |
| 3 | خدمات سيارات | Car Services | Workshops, tow trucks, transport, polish |
| 4 | جوالات | Mobile Phones | All types + accessories |
| 5 | أجهزة | Appliances | Electrical, home, tech |
| 6 | وظائف | Jobs | **100% Free** — no commission |
| 7 | رحلات وصيد | Trips & Hunting | Camping, hunting, RVs, off-road |
| 8 | حيوانات وطيور | Animals & Birds | ⚠️ **Cats & dogs strictly prohibited** |
| 9 | أثاث | Furniture | Home and office |
| 10 | خدمات | Services | Cleaning, plumbing, electrical, moving |
| 11 | أطعمة ومشروبات | Food & Beverages | — |
| 12 | تحف وهدايا | Antiques, Gifts & Personal | — |
| 13 | كتب وفنون | Books & Arts | Books, crafts, photography |
| 14 | برمجة | Programming | Apps, websites, design, cybersecurity |
| 15 | كل الحراج | All Haraj | General classifieds |

---

## 5. Core Features Summary

### 5.1 User App (Mobile + Web)

| Feature | Description |
|---|---|
| **Auth** | Email or Phone (Firebase OTP) → Sanctum token |
| **Ad Posting** | Images, description, price, region/city (mandatory). Cars have extra required fields. |
| **Ad Lifecycle** | Auto-expire after 30 days + pre-expiry notification |
| **Ad Boost** | "Refresh" to push ad back to top of results |
| **Search & Filter** | Meilisearch-powered. Filter by city, category, keywords |
| **Feed** | Chronological new ads with category tabs |
| **Chat** | Firebase Firestore real-time messaging (buyer ↔ seller) |
| **Commission Calculator** | Auto-calculates 0.5% on price input. 90 SAR flat for dealerships. |
| **Ethical Pledge** | Mandatory oath screen before ad publish |
| **Disclaimer** | Fixed text injected under every ad |
| **Ratings** | Stars + comments (requires ethical pledge to rate). Admin-reviewed comments. |
| **Verified Badge** | Auto-granted for consistent commission payers |
| **Report Ad** | Sends to admin review queue |
| **Smart Follow** | Follow categories → push notifications for new ads |
| **City Notifications** | New ads in user's city |
| **Favorites** | Save/bookmark ads |

### 5.2 Admin Panel

| Feature | Description |
|---|---|
| **User Management** | View, activate, deactivate accounts |
| **Ad Moderation** | Review queue for flagged ads. Edit/delete any ad. |
| **Category Management** | CRUD categories and subcategories |
| **City/Region Management** | Manage active cities and regions |
| **CMS** | About Us, Terms & Conditions, Contact Us |
| **Rating Management** | Edit/delete comments, monitor ratings |
| **Commission Tracking** | Set global %, track Due vs. Paid |
| **Auto-Verification** | Payment triggers automatic verified badge |
| **Banner Management** | Upload banners with deep links (ad, WhatsApp, URL) + scheduling |
| **Notification Engine** | Targeted push by city/category. Broadcast messages. Delivery reports. |
| **Analytics** | Financial reports, ad distribution by city, search term analytics |
| **Subscription Infrastructure** | Backend-ready for future monthly/yearly packages |

### 5.3 Banner Advertising System

| Feature | Description |
|---|---|
| **Placement** | Homepage top carousel |
| **Link Types** | Internal ad deep link, WhatsApp number, External URL |
| **Scheduling** | Start date/time + End date/time (cron-based auto show/hide) |
| **Admin UI** | Upload, arrange, preview, analytics |

---

## 6. Payment Flow (Commission)

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Seller     │     │  App/Web    │     │  Payment     │     │   Laravel    │
│  completes  │────▶│  "Declare   │────▶│  Gateway     │────▶│   Webhook    │
│  sale       │     │   Sale"     │     │  (Tap/       │     │   Listener   │
│  outside    │     │  button     │     │   Moyasar)   │     │              │
│  the app    │     │             │     │              │     │  Updates:    │
└─────────────┘     └─────────────┘     └──────────────┘     │  • Payment   │
                         │                                    │    status    │
                    Calculates:                               │  • Verified  │
                    • 0.5% of price                           │    badge     │
                    • OR 90 SAR (dealer)                      └──────────────┘
```

---

## 7. Notification Strategy

| Trigger | Channel | Target |
|---|---|---|
| New ad in followed category | FCM Push | Subscribed users |
| New ad in user's city | FCM Push | Users in that city |
| Ad expiring (3 days before) | FCM Push + In-app | Ad owner |
| Ad deleted by admin | In-app | Ad owner |
| New rating received | FCM Push + In-app | Rated user |
| Commission payment confirmed | In-app | Paying user |
| Admin broadcast | FCM Push | Targeted segment |
| New chat message | FCM Push | Recipient |
| Banner campaign start | System (cron) | Automated |

---

## 8. Security & Compliance

- **Data Residency**: All data stored in DigitalOcean's available Middle East or nearest region
- **HTTPS**: Enforced everywhere (Let's Encrypt)
- **API Rate Limiting**: Laravel throttle middleware
- **Input Validation**: Server-side validation on all endpoints
- **Image Moderation**: Manual review for reported content
- **PDPL Compliance**: Saudi Personal Data Protection Law considerations (privacy policy, data handling)
- **Content Policy**: Cats/dogs detection via keyword filters + manual moderation
- **SQL Injection / XSS**: Laravel's built-in protections + Next.js escaping

---

## 9. Directory Structure (Monorepo)

```
barq-wadih-tech/
├── backend/                    # Laravel API
│   ├── app/
│   │   ├── Http/Controllers/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Jobs/
│   │   └── Notifications/
│   ├── database/migrations/
│   ├── routes/api.php
│   └── ...
├── frontend/                   # Next.js (Web + Admin)
│   ├── src/
│   │   ├── app/
│   │   │   ├── [locale]/       # i18n routing
│   │   │   │   ├── (public)/   # Public pages
│   │   │   │   ├── (auth)/     # Auth pages
│   │   │   │   └── admin/      # Admin panel
│   │   ├── components/
│   │   ├── lib/
│   │   ├── styles/
│   │   └── messages/           # ar.json, en.json
│   └── ...
├── mobile/                     # Flutter app
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   └── ...
├── docs/                       # Project documentation
│   ├── PROJECT_OVERVIEW.md
│   ├── DATABASE_SCHEMA.md
│   └── SPRINT_LIST.md
└── docker-compose.yml          # Local dev (MySQL, Redis, Meilisearch)
```

---

## 10. Third-Party Services

| Service | Purpose | Cost Model |
|---|---|---|
| **Firebase Auth** | Phone OTP verification | Free tier (10k/month) then pay-per-use |
| **Firebase Firestore** | Real-time chat | Free tier (1GB storage, 50k reads/day) then pay-per-use |
| **Firebase FCM** | Push notifications | Free |
| **DigitalOcean Spaces** | Image/media storage + CDN | $5/month (250GB storage, 1TB transfer) |
| **DigitalOcean Droplet** | Server (Laravel, Meilisearch, Redis, Nginx) | ~$96/month (16GB RAM) |
| **Tap / Moyasar** | Payment processing (commission collection) | ~2.5% per transaction |
| **Meilisearch** | Full-text search engine | Free (self-hosted, open source) |
| **GitHub** | Source code + CI/CD | Free for private repos |

**Estimated Monthly Infrastructure Cost: ~$105-120/month** (before payment gateway transaction fees)
