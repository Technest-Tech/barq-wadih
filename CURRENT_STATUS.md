# Barq Wadih — Current Development Status

> **Last Updated**: 2026-04-16
> **Active Sprint**: Sprint 17 (next)
> **Overall Phase**: Phase 5 — Admin Panel

---

## Sprint Completion Overview

| Sprint | Title | Status |
|---|---|---|
| 1 | Project Scaffolding & Dev Environment | ✅ Complete |
| 2 | Database Schema, Migrations & Seeders | ✅ Complete |
| 3 | Authentication & User Management | ✅ Complete |
| 3.5 | Homepage UI (Bonus) | ✅ Complete |
| 4 | Categories, Regions & Cities API + UI | ✅ Complete |
| 5 | Ad Posting & Management (Backend + Web) | ✅ Complete |
| 6 | Ad Posting & Management (Flutter Mobile) | ✅ Complete |
| 7 | Ad Feed, Search & Filtering | ✅ Complete |
| 8 | Real-Time Chat (Firebase Firestore) | ✅ Complete |
| 9 | Favorites, Ratings & Reporting | ✅ Complete |
| 10 | Push Notifications & Smart Follow | ✅ Complete |
| **11** | **Commission Payment System** | ⚠️ **Skipped — Deferred** |
| 12 | Banner Advertising System | ✅ Complete |
| 13 | Ad Boost & Refresh Feature | ✅ Complete |
| 14 | Admin Panel Foundation & User Management | ✅ Complete |
| 15 | Admin Ad Moderation & Content Management | ✅ Complete |
| 16 | Admin Commission & Analytics Dashboard | ✅ Complete |
| **17** | **Admin Notification Engine & Banner Mgmt** | 🚀 **Next** |
| 18 | SEO, Performance & Optimization | ⏳ Pending |
| 19 | Localization, RTL Polish & Accessibility | ⏳ Pending |
| 20 | Testing, Security Audit & Deployment | ⏳ Pending |
| 21 | App Store Submission & Launch | ⏳ Pending |

> ⚠️ **Sprint 11** was skipped. The `commission_payments` table exists and Sprint 16 analytics use it. Sprint 11 (payment gateway integration) must be completed before public launch.

---

## Phase 1: Foundation & Infrastructure (Sprints 1–3) ✅

- Monorepo: `backend/`, `frontend/`, `mobile/`, `docs/`, `infra/`
- Laravel 12 + Sanctum, Next.js 16 + next-intl, Flutter 3.32 + Riverpod
- 24 migrations, 22 Eloquent models, 20 enums
- Firebase phone OTP + email/password auth
- Docker Compose (MySQL 8, Redis 7, Meilisearch)
- CI/CD: 3 GitHub Actions workflows

## Phase 2: Core Marketplace (Sprints 4–7) ✅

- Categories API (hierarchical tree) + regions/cities API
- Ad CRUD with image upload (DO Spaces), dynamic category fields (EAV)
- Commission auto-calculator (0.5% / 90 SAR flat)
- Meilisearch full-text search with Arabic tokenization
- Next.js + Flutter: ad posting, feed, search, filters

## Phase 3: Engagement & Communication (Sprints 8–10) ✅

- Firebase Firestore real-time chat with unread tracking
- Favorites, ratings, reporting system
- Push notifications & smart follow (category-based triggers)

## Phase 4: Monetization (Sprints 12–13) ✅

- Banner advertising system with carousel, impression/click tracking
- Ad boost (72h premium pin) + refresh (24h cooldown re-timestamp)
- Hourly boost expiry + daily banner deactivation schedulers

---

## ✅ Sprint 14 — Admin Panel Foundation & User Management

- Admin layout (dark theme sidebar + header)
- `DashboardController::stats()` — KPIs with Chart.js charts
- `AdminUserController` — CRUD (list, detail, updateStatus, updateRole)
- User management page with search, filters, role/status management
- `EnsureAdmin` middleware

### Admin API Routes (5)
```
GET    /api/v1/admin/dashboard/stats
GET    /api/v1/admin/users
GET    /api/v1/admin/users/{user}
PATCH  /api/v1/admin/users/{user}/status
PATCH  /api/v1/admin/users/{user}/role
```

---

## ✅ Sprint 15 — Admin Ad Moderation & Content Management

### Backend (5 controllers, 29 routes)
| Controller | Endpoints |
|---|---|
| `AdminAdController` | index (12 filters), show, approve, reject, destroy, restore |
| `AdminReportController` | index, show, resolve (with side-effects), dismiss |
| `AdminCategoryController` | CRUD + fields CRUD + batch reorder + toggle active |
| `AdminRegionController` | regions list, cities list, toggle active, city update |
| `AdminStaticPageController` | CRUD with bilingual content + publish toggle |

### Frontend (5 pages)
| Page | Features |
|---|---|
| `/admin/ads` | Filter bar (12 params), table, quick actions (✅❌🗑️♻️) |
| `/admin/reports` | Priority queue, resolve modal (4 admin actions), dismiss |
| `/admin/categories` | Tree view + CRUD modals + inline field editor |
| `/admin/regions` | Accordion layout + toggle switches + city edit |
| `/admin/pages` | CMS list + bilingual rich text editor |

---

## ✅ Sprint 16 — Admin Commission & Analytics Dashboard

### Backend (2 controllers, 9 routes)
| Controller | Endpoints |
|---|---|
| `AdminCommissionController` | index (filterable), show, updateStatus, summary, export (CSV) |
| `AdminAnalyticsController` | revenue (time series), adsByCity (top 20), searchTerms, zeroResults |

### Frontend (3 pages + detail)
| Page | Features |
|---|---|
| `/admin/commissions` | KPI cards, filter toolbar, data table with inline status dropdown, CSV export |
| `/admin/commissions/[id]` | Commission detail + related ad/user + status change + timeline |
| `/admin/analytics` | Period selector, revenue chart, commission doughnut, city distribution bars |
| `/admin/search-analytics` | Top search terms, zero-result queries, volume chart, platform breakdown |

---

## 🚀 Sprint 17 — Admin Notification Engine & Banner Management — NEXT

### Scope (from SPRINT_LIST.md)
- Admin notification campaign builder (target by city/category/all)
- Notification scheduling and delivery tracking
- Delivery reports (sent, delivered, opened counts)
- Banner management panel (upload, preview, schedule, analytics)
- Banner performance reports (impressions, clicks, CTR)
- System settings management UI

### Already pre-wired in sidebar
```
🖼️ /admin/banners        → البانرات (disabled — Sprint 17)
🔔 /admin/notifications  → الإشعارات (disabled — Sprint 17)
⚙️ /admin/settings       → الإعدادات (disabled — Sprint 17)
```

---

## Environment

| Setting | Value |
|---|---|
| **DB** | MySQL 9.3 (local Homebrew), `barq_wadih` database |
| **DB Credentials** | `DB_USERNAME=new_user` / `DB_PASSWORD=414$Ahmed` |
| **API URL** | `http://127.0.0.1:8000/api/v1` |
| **Backend PHP** | `/opt/homebrew/bin/php` |
| **Node.js** | `/opt/homebrew/bin/node` |
| **Flutter** | `/Users/ahmedomar/fvm/versions/3.24.3/bin/flutter` |
| **Scout Driver** | `collection` (no Meilisearch needed locally) |
| **Firebase Project** | `barqwadih-40271` |

---

## Blockers
- None

## Known Gaps
- ⚠️ **Sprint 11** (Commission Payment System) — payment gateway integration must complete before launch
