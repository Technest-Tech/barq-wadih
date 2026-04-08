# Barq Wadih (برق واضح) — Sprint List

> **Methodology**: 2-week sprints | **Developer**: Solo (Claude vibe coding)
>
> Each sprint is designed to be self-contained and shippable. Sprints are ordered by dependency — each one builds on the previous.

---

## Phase 1: Foundation & Infrastructure (Sprints 1–3)

### Sprint 1 — Project Scaffolding & Dev Environment
Setup monorepo structure, Laravel API scaffold, Next.js scaffold, Flutter scaffold, Docker Compose for local dev (MySQL, Redis, Meilisearch), CI/CD pipeline, environment configuration, and DigitalOcean Droplet provisioning.

### Sprint 2 — Database Schema, Migrations & Seeders
All 25 MySQL migrations in dependency order, Eloquent models with relationships, factory classes, seeders for regions/cities (all Saudi cities), categories with subcategories, category custom fields (Cars fields), and system_settings defaults.

### Sprint 3 — Authentication & User Management
Firebase phone OTP integration, email/password auth, Laravel Sanctum token issuance, user registration/login API endpoints, Next.js auth pages (login, register, forgot password), Flutter auth screens, RTL Arabic-first layouts, and user profile CRUD.

---

## Phase 2: Core Marketplace (Sprints 4–7)

### Sprint 4 — Categories, Regions & Cities API + UI
Categories API (hierarchical tree), regions/cities API, Meilisearch initial setup with Laravel Scout, Next.js category browsing pages, Flutter category/city selection screens, and horizontal category tab bar (like Haraj reference).

### Sprint 5 — Ad Posting & Management (Backend + Web)
Ad CRUD API with image upload to DO Spaces, dynamic category fields (EAV), mandatory field validation (region/city, car-specific fields), ethical pledge screen, commission auto-calculator (0.5% / 90 SAR flat), ad expiry logic (30-day lifecycle), disclaimer text injection, Next.js ad posting form, and ad management dashboard for users.

### Sprint 6 — Ad Posting & Management (Flutter Mobile)
Flutter ad creation flow (multi-step form), image picker with compression and upload, location/city selection, dynamic category fields rendering, pledge acceptance screen, commission preview, and user's "My Ads" management screen.

### Sprint 7 — Ad Feed, Search & Filtering
Meilisearch full indexing (Arabic tokenization, typo tolerance), search API with filters (city, category, price range, custom fields), Next.js homepage feed (chronological with boosted ads on top), ad detail page (seller info, images gallery, disclaimer), Flutter home feed screen, search/filter UI, ad detail screen, and nearby ads sorting.

---

## Phase 3: Engagement & Communication (Sprints 8–10)

### Sprint 8 — Real-Time Chat (Firebase Firestore)
Firestore data structure setup, security rules, conversation creation on "Contact Seller", message sending/receiving with real-time listeners, unread count tracking, chat list UI (Next.js + Flutter), message screen UI, image sharing in chat, and chat notification triggers.

### Sprint 9 — Favorites, Ratings & Reporting
Favorites/bookmarks API and UI (both platforms), rating system with ethical pledge requirement, star + comment submission, admin-reviewable comments, verified badge auto-grant logic, report ad flow (reason selection + description), admin review queue for reports, and user profile page with ratings display.

### Sprint 10 — Push Notifications & Smart Follow
FCM integration (Laravel → Firebase Admin SDK), user device token registration, category follow/unfollow API, smart follow: new ad triggers push to followers, city-based notifications, ad expiry pre-notifications (3 days before), rating received notification, notification preferences screen, and in-app notification center (list + read/unread).

---

## Phase 4: Monetization (Sprints 11–13)

### Sprint 11 — Commission Payment System
Payment gateway integration (Tap or Moyasar), "Declare Sale" flow (seller self-reports sale), commission calculation and payment checkout, payment webhook handler (status updates), payment history for users, auto-verified badge on consistent payments, and commission status tracking on ads.

### Sprint 12 — Banner Advertising System
Banner CRUD API, image upload, deep link configuration (ad/WhatsApp/URL), scheduled start/end with cron job for auto show/hide, homepage banner carousel (Next.js + Flutter), click tracking and impression counting, banner analytics, and admin banner management UI.

### Sprint 13 — Ad Boost & Refresh Feature
Boost/refresh API endpoint, boosted ads sorting (boosted first in feed), boost expiry logic, boost history tracking, boost UI on user's ad management, and integration with payment (if premium boost is paid).

---

## Phase 5: Admin Panel (Sprints 14–17)

### Sprint 14 — Admin Panel Foundation & User Management
Admin layout and navigation (Next.js `/admin/*` route group), admin authentication and role-based access control, admin dashboard with KPI cards (total users, ads, revenue, active banners), user management (list, search, view details, activate/deactivate), and user detail page with ad history and payment history.

### Sprint 15 — Admin Ad Moderation & Content Management
Ad moderation queue (flagged/reported ads), ad review workflow (approve, reject with reason, delete), ad listing with filters (city, category, status, date range), category CRUD management UI, city/region management UI, and CMS editor for static pages (About Us, Terms, Contact).

### Sprint 16 — Admin Commission & Analytics Dashboard
Commission tracking dashboard (due vs. paid, totals, trends), payment history with search and export, commission rate configuration, financial reports (daily, weekly, monthly revenue charts), ad distribution by city (map/chart visualization), and search term analytics (top searched keywords, zero-result queries).

### Sprint 17 — Admin Notification Engine & Banner Management
Admin notification campaign builder (target by city/category/all), notification scheduling and delivery tracking, delivery reports (sent, delivered, opened counts), banner management panel (upload, preview, schedule, analytics), banner performance reports (impressions, clicks, CTR), and system settings management UI.

---

## Phase 6: Polish & Launch Prep (Sprints 18–20)

### Sprint 18 — SEO, Performance & Optimization
Next.js SSR/SSG optimization for ad pages (SEO), meta tags, Open Graph, structured data (Schema.org for Product), image optimization (lazy loading, WebP conversion, thumbnails), API response caching (Redis), database query optimization (N+1 prevention, index tuning), Meilisearch index optimization, and bundle size optimization.

### Sprint 19 — Localization, RTL Polish & Accessibility
Complete Arabic/English translation coverage (all strings), RTL layout audit and fixes across all pages, locale switcher (Arabic ↔ English), date/time formatting (Hijri calendar option), currency formatting (SAR), accessibility audit (ARIA labels, keyboard navigation), and responsive design audit (mobile, tablet, desktop).

### Sprint 20 — Testing, Security Audit & Deployment
End-to-end testing (critical flows: auth, post ad, search, chat, payment), API integration tests, security audit (rate limiting, input validation, CORS, XSS prevention), PDPL compliance review (privacy policy, data handling), production deployment to DigitalOcean (SSL, Nginx, PHP-FPM tuning), Meilisearch production configuration, monitoring setup, and backup strategy.

---

## Phase 7: Mobile Release (Sprint 21)

### Sprint 21 — App Store Submission & Launch
Flutter app final polish and platform-specific adjustments, App Store (iOS) submission with Arabic metadata and screenshots, Google Play Store submission with Arabic listing, deep linking configuration (universal links / app links), app review response preparation, and launch monitoring and hotfix readiness.

---

## Future Sprints (Post-Launch Backlog)

### Sprint 22+ — Subscription System Implementation
Subscription plans CRUD, user subscription purchase flow, plan-based feature gating, auto-renewal with payment gateway, and subscription management in admin panel.

### Sprint 23+ — Advanced Analytics & ML
User behavior analytics, recommendation engine (similar ads), fraud detection patterns, automated content moderation (AI image scanning for prohibited content), and A/B testing framework.

### Sprint 24+ — Marketplace Enhancements
Auction/bidding system, promoted listings tiers, seller storefront pages, bulk ad posting for dealers, and advanced map-based browsing.

---

## Sprint Summary Table

| Sprint | Title | Duration | Phase |
|---|---|---|---|
| 1 | Project Scaffolding & Dev Environment | 2 weeks | Foundation |
| 2 | Database Schema, Migrations & Seeders | 2 weeks | Foundation |
| 3 | Authentication & User Management | 2 weeks | Foundation |
| 4 | Categories, Regions & Cities API + UI | 2 weeks | Core |
| 5 | Ad Posting & Management (Backend + Web) | 2 weeks | Core |
| 6 | Ad Posting & Management (Flutter) | 2 weeks | Core |
| 7 | Ad Feed, Search & Filtering | 2 weeks | Core |
| 8 | Real-Time Chat (Firebase Firestore) | 2 weeks | Engagement |
| 9 | Favorites, Ratings & Reporting | 2 weeks | Engagement |
| 10 | Push Notifications & Smart Follow | 2 weeks | Engagement |
| 11 | Commission Payment System | 2 weeks | Monetization |
| 12 | Banner Advertising System | 2 weeks | Monetization |
| 13 | Ad Boost & Refresh Feature | 2 weeks | Monetization |
| 14 | Admin Panel Foundation & User Management | 2 weeks | Admin |
| 15 | Admin Ad Moderation & Content Management | 2 weeks | Admin |
| 16 | Admin Commission & Analytics Dashboard | 2 weeks | Admin |
| 17 | Admin Notification Engine & Banner Management | 2 weeks | Admin |
| 18 | SEO, Performance & Optimization | 2 weeks | Polish |
| 19 | Localization, RTL Polish & Accessibility | 2 weeks | Polish |
| 20 | Testing, Security Audit & Deployment | 2 weeks | Polish |
| 21 | App Store Submission & Launch | 2 weeks | Release |
| **Total** | **21 sprints × 2 weeks** | **~42 weeks (~10 months)** | — |
