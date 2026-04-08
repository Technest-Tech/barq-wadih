# Sprint 1 — Project Scaffolding & Dev Environment

> **Phase**: 1 – Foundation & Infrastructure
> **Duration**: 2 weeks
> **Sprint Dates**: TBD → TBD

---

## Sprint Goal

Stand up the monorepo with a working Laravel API, Next.js frontend, and Flutter mobile scaffold — all wired to a local Docker dev environment (MySQL 8, Redis, Meilisearch) — so that every subsequent sprint can start coding features immediately without environment friction.

---

## Prerequisites / Setup Steps

Before starting the tasks, ensure the following are available:

| Prerequisite | Notes |
|---|---|
| **PHP 8.3+** | Installed locally via Homebrew (`brew install php`) |
| **Composer 2.x** | PHP dependency manager |
| **Node.js 20 LTS + npm** | For Next.js |
| **Flutter 3.x + Dart SDK** | For mobile app |
| **Docker Desktop** | For MySQL, Redis, Meilisearch containers |
| **Git** | Repo initialized, GitHub remote created |
| **GitHub account** | For CI/CD (GitHub Actions) |
| **DigitalOcean account** | Droplet + Spaces (can be deferred to Sprint 20) |
| **Code editor** | VS Code / Cursor recommended |

---

## Task Breakdown

### Task 1 — Initialize Monorepo & Git Configuration

**Description**: Create the root monorepo structure, initialize Git, set up `.gitignore`, create the root `README.md`, and push to GitHub.

**Steps**:
1. Create root directory `barq-wadih-tech/` (already exists with docs)
2. Create subdirectories: `backend/`, `frontend/`, `mobile/`, `docs/`, `infra/`
3. Move existing docs (`PROJECT_OVERVIEW.md`, `DATABASE_SCHEMA.md`, `SPRINT_LIST.md`) into `docs/`
4. Create root `.gitignore` covering Laravel, Next.js, Flutter, Docker, IDE files
5. Create root `README.md` with project name, tech stack summary, and quick-start instructions
6. Create root `.editorconfig` for consistent formatting
7. Initialize Git repo and push to GitHub

**Acceptance Criteria**:
- [ ] Monorepo root has `backend/`, `frontend/`, `mobile/`, `docs/`, `infra/` directories
- [ ] `.gitignore` covers all three stacks (PHP, Node, Flutter) + Docker + OS files
- [ ] `README.md` exists with project name in Arabic & English, tech stack table, and "Getting Started" section
- [ ] Successful `git push` to GitHub remote

**Relevant DB Tables**: None

**API Endpoints**: None

---

### Task 2 — Docker Compose for Local Dev Services

**Description**: Create a `docker-compose.yml` at the monorepo root that spins up MySQL 8, Redis, and Meilisearch for local development.

**Steps**:
1. Create `docker-compose.yml` with three services:
   - `mysql` — MySQL 8.0, `utf8mb4_unicode_ci`, port 3306, named volume for persistence
   - `redis` — Redis 7.x, port 6379
   - `meilisearch` — Meilisearch latest, port 7700, master key configured
2. Create `.env.docker` (or use root `.env`) with default credentials
3. Add a `Makefile` or shell script (`scripts/dev-up.sh`, `scripts/dev-down.sh`) for convenience
4. Test: `docker compose up -d` → all three services healthy

**Acceptance Criteria**:
- [ ] `docker compose up -d` starts all three services without errors
- [ ] MySQL accepts connections on `localhost:3306` with configured credentials
- [ ] Redis responds to `PING` on `localhost:6379`
- [ ] Meilisearch dashboard accessible at `http://localhost:7700`
- [ ] Data persists between `docker compose down` and `docker compose up`
- [ ] `.env.docker` or `.env` has sensible defaults (non-production passwords)

**Relevant DB Tables**: None (containers only; schema is Sprint 2)

**API Endpoints**: None

---

### Task 3 — Laravel API Scaffold

**Description**: Initialize a fresh Laravel 11 project inside `backend/`, configure it to connect to the Docker services, and verify the base install works.

**Steps**:
1. Run `composer create-project laravel/laravel backend` (or install into existing dir)
2. Configure `.env` for Docker MySQL, Redis, Meilisearch:
   ```
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=barq_wadih
   DB_USERNAME=barq_user
   DB_PASSWORD=<from docker-compose>

   CACHE_DRIVER=redis
   QUEUE_CONNECTION=redis
   SESSION_DRIVER=redis
   REDIS_HOST=127.0.0.1
   REDIS_PORT=6379

   SCOUT_DRIVER=meilisearch
   MEILISEARCH_HOST=http://127.0.0.1:7700
   MEILISEARCH_KEY=<master key from docker-compose>
   ```
3. Install essential packages:
   - `laravel/sanctum` — API token auth
   - `laravel/scout` + `meilisearch/meilisearch-php` — search
   - `league/flysystem-aws-s3-v3` — DO Spaces (S3-compatible) file storage
4. Run `php artisan migrate` to confirm DB connection (default Laravel tables)
5. Create a health-check endpoint: `GET /api/health` → `{ "status": "ok", "timestamp": "..." }`
6. Configure CORS for `http://localhost:3000` (Next.js dev server)
7. Set `APP_TIMEZONE=Asia/Riyadh`
8. Configure rate limiting defaults in `RouteServiceProvider` or `bootstrap/app.php`

**Acceptance Criteria**:
- [ ] `php artisan serve` starts without errors
- [ ] `GET http://localhost:8000/api/health` returns `200 { "status": "ok" }`
- [ ] `php artisan migrate` runs successfully against Docker MySQL
- [ ] Sanctum, Scout, and S3 packages installed in `composer.json`
- [ ] `.env.example` updated with all required variables (no secrets)
- [ ] CORS configured to allow requests from `localhost:3000`

**Relevant DB Tables**: `personal_access_tokens` (auto-created by Sanctum migration)

**API Endpoints**:

| Method | Path | Description | Response |
|---|---|---|---|
| `GET` | `/api/health` | Health check | `200 { "status": "ok", "timestamp": "2026-04-08T12:00:00Z" }` |

---

### Task 4 — Next.js Frontend Scaffold

**Description**: Initialize a Next.js 14+ project with App Router inside `frontend/`, configured for TypeScript, RTL Arabic-first design, and i18n.

**Steps**:
1. Run `npx -y create-next-app@latest frontend` with TypeScript, App Router, no Tailwind (vanilla CSS)
2. Install dependencies:
   - `next-intl` — internationalization
   - `@tanstack/react-query` — data fetching / cache
3. Set up i18n:
   - Create `frontend/src/messages/ar.json` with basic keys (`app.name`, `app.description`, `common.loading`, etc.)
   - Create `frontend/src/messages/en.json` with same keys
   - Configure `next-intl` middleware for `[locale]` routing (default: `ar`)
4. Create design system foundation:
   - `frontend/src/styles/globals.css` — CSS reset, CSS custom properties (colors, fonts, spacing, radii)
   - `frontend/src/styles/tokens.css` — design tokens
   - Import Google Fonts: **IBM Plex Sans Arabic** (Arabic) + **Inter** (English/numerals)
5. Set up routing structure:
   ```
   src/app/
   ├── [locale]/
   │   ├── layout.tsx          # RTL/LTR wrapper, font loading
   │   ├── page.tsx            # Homepage placeholder
   │   ├── (public)/           # Public pages (future: ads, search)
   │   ├── (auth)/             # Auth pages (future: login, register)
   │   └── admin/              # Admin panel (future)
   │       └── layout.tsx      # Admin layout placeholder
   ```
6. Create a minimal homepage that fetches `/api/health` from Laravel and displays it
7. Configure `next.config.js` for `images.remotePatterns` (DO Spaces domain)

**Acceptance Criteria**:
- [ ] `npm run dev` starts on `http://localhost:3000` without errors
- [ ] Homepage renders in Arabic (RTL direction) by default
- [ ] Visiting `/en` switches to English (LTR direction)
- [ ] Design tokens (colors, fonts, spacing) defined in CSS custom properties
- [ ] IBM Plex Sans Arabic font loads for Arabic text
- [ ] Homepage successfully fetches and displays health check from Laravel API
- [ ] Route group structure exists: `(public)`, `(auth)`, `admin`
- [ ] No Tailwind — only vanilla CSS

**Relevant DB Tables**: None

**API Endpoints**: Consumes `GET /api/health` (built in Task 3)

---

### Task 5 — Flutter Mobile Scaffold

**Description**: Initialize a Flutter project inside `mobile/`, set up the project structure, configure dependencies, and create a minimal working app.

**Steps**:
1. Run `flutter create --org com.barqwadih mobile` (or `flutter create` inside `mobile/`)
2. Set up project structure:
   ```
   mobile/lib/
   ├── main.dart
   ├── app.dart                    # MaterialApp configuration
   ├── config/
   │   ├── theme.dart              # App theme (RTL, Arabic font, colors)
   │   ├── routes.dart             # Route definitions
   │   └── constants.dart          # API base URL, etc.
   ├── core/
   │   ├── api/
   │   │   └── api_client.dart     # Dio HTTP client wrapper
   │   ├── di/                     # Dependency injection setup
   │   └── utils/                  # Helpers
   ├── features/                   # Feature-first architecture
   │   └── home/
   │       └── home_screen.dart    # Placeholder
   ├── l10n/                       # Localization
   │   ├── app_ar.arb
   │   └── app_en.arb
   └── shared/
       ├── widgets/                # Reusable widgets
       └── models/                 # Shared data models
   ```
3. Install core packages in `pubspec.yaml`:
   - `dio` — HTTP client
   - `flutter_riverpod` — state management
   - `go_router` — navigation
   - `flutter_localizations` + `intl` — i18n
   - `cached_network_image` — image caching
   - `flutter_secure_storage` — token storage
4. Configure Arabic-first theme:
   - Default locale: `ar`
   - RTL text direction
   - Arabic font (IBM Plex Sans Arabic from Google Fonts via `google_fonts` package)
   - Brand color palette matching web
5. Create `ApiClient` with Dio configured for:
   - Base URL: `http://10.0.2.2:8000/api` (Android emulator → host)
   - Accept: `application/json`
   - Interceptor: attach Sanctum token from secure storage
6. Test: app launches, shows Arabic "برق واضح" title, calls health check

**Acceptance Criteria**:
- [ ] `flutter run` launches the app on emulator/simulator without errors
- [ ] App displays in Arabic with RTL layout by default
- [ ] Dio `ApiClient` configured with base URL and JSON headers
- [ ] Project structure matches feature-first architecture pattern
- [ ] Localization files (`app_ar.arb`, `app_en.arb`) exist with basic keys
- [ ] Brand theme (colors, typography) applied

**Relevant DB Tables**: None

**API Endpoints**: Consumes `GET /api/health` (built in Task 3)

---

### Task 6 — API Client & Shared Config (Frontend ↔ Backend)

**Description**: Create a typed API client layer in the Next.js frontend for communicating with the Laravel backend, and establish shared configuration patterns.

**Steps**:
1. Create `frontend/src/lib/api/client.ts`:
   - Base URL from `NEXT_PUBLIC_API_URL` env variable
   - Fetch wrapper with JSON headers, error handling, auth token injection
   - Generic `get<T>()`, `post<T>()`, `put<T>()`, `delete<T>()` methods
2. Create `frontend/src/lib/api/types.ts`:
   - `ApiResponse<T>` generic type: `{ data: T, message?: string }`
   - `PaginatedResponse<T>`: `{ data: T[], meta: { current_page, last_page, per_page, total } }`
   - `ApiError` type: `{ message: string, errors?: Record<string, string[]> }`
3. Create `frontend/src/lib/api/endpoints.ts`:
   - Central registry of all API paths (start with just `HEALTH: '/health'`)
4. Create `frontend/.env.local`:
   ```
   NEXT_PUBLIC_API_URL=http://localhost:8000/api
   ```
5. Create `frontend/src/lib/hooks/useApi.ts` — TanStack Query wrapper hook
6. Add error boundary component `frontend/src/components/ErrorBoundary.tsx`

**Acceptance Criteria**:
- [ ] `ApiClient` class/module exists with typed methods
- [ ] `ApiResponse<T>` and `PaginatedResponse<T>` types defined
- [ ] API base URL read from environment variable
- [ ] Health check works through the API client (not raw fetch)
- [ ] Error handling returns typed `ApiError` objects
- [ ] `useApi` hook wraps TanStack Query for data fetching

**Relevant DB Tables**: None

**API Endpoints**: Consumes `GET /api/health`

---

### Task 7 — CI/CD Pipeline (GitHub Actions)

**Description**: Set up GitHub Actions workflows for automated linting, testing, and deployment preparation.

**Steps**:
1. Create `.github/workflows/backend.yml`:
   - Trigger: push/PR to `main` and `develop` branches
   - Matrix: PHP 8.3
   - Steps: checkout → composer install → copy `.env.testing` → `php artisan test` → PHPStan level 5
   - Services: MySQL 8 (GitHub Actions service container)
2. Create `.github/workflows/frontend.yml`:
   - Trigger: push/PR to `main` and `develop`
   - Steps: checkout → npm ci → `npm run lint` → `npm run build` → `npm run test` (if tests exist)
3. Create `.github/workflows/mobile.yml`:
   - Trigger: push/PR to `main` and `develop`
   - Steps: checkout → Flutter setup → `flutter analyze` → `flutter test`
4. Create branch protection rules documentation (in `docs/`):
   - `main`: requires PR + CI pass
   - `develop`: working branch
5. Create git branching strategy doc: `docs/GIT_STRATEGY.md`
   - Feature branches: `feature/sprint-XX-description`
   - Bugfix branches: `fix/description`
   - Release branches: `release/vX.Y.Z`

**Acceptance Criteria**:
- [ ] Push to `develop` triggers all three CI workflows
- [ ] Backend workflow: installs deps, runs tests, passes PHPStan
- [ ] Frontend workflow: lints, builds successfully
- [ ] Mobile workflow: analyzes and tests
- [ ] `docs/GIT_STRATEGY.md` documents branching strategy
- [ ] All workflows use caching (Composer cache, npm cache, Flutter pub cache)

**Relevant DB Tables**: None

**API Endpoints**: None

---

### Task 8 — Laravel API Structure & Base Classes

**Description**: Set up the Laravel API architecture — base controller, form requests, API resources, exception handler, and middleware — so Sprint 2+ can follow a consistent pattern.

**Steps**:
1. Create `app/Http/Controllers/Api/V1/BaseController.php`:
   - Standard JSON response helpers: `successResponse()`, `errorResponse()`, `paginatedResponse()`
   - Response format:
     ```json
     {
       "success": true,
       "message": "...",
       "data": { ... },
       "meta": { ... }
     }
     ```
2. Create `app/Traits/ApiResponses.php` trait (used by BaseController)
3. Create `app/Exceptions/Handler.php` customization:
   - All exceptions return JSON (no HTML for API)
   - Validation: 422 with field errors
   - Auth: 401
   - Not found: 404
   - Rate limit: 429
   - Server error: 500 (hide details in production)
4. Set up route versioning:
   - `routes/api.php` → includes `routes/api/v1.php`
   - All v1 routes prefixed with `/api/v1/`
   - Move health check to `/api/v1/health`
5. Create `app/Http/Middleware/SetLocale.php`:
   - Read `Accept-Language` header or `?lang=` param
   - Set app locale to `ar` or `en`
6. Create `app/Http/Middleware/ForceJsonResponse.php`:
   - Ensure all API responses are JSON
7. Register middleware in `bootstrap/app.php`

**Acceptance Criteria**:
- [ ] `BaseController` with `successResponse()` and `errorResponse()` helpers
- [ ] All API exceptions return consistent JSON format (no HTML stack traces)
- [ ] Routes versioned under `/api/v1/`
- [ ] `GET /api/v1/health` works with new response format: `{ "success": true, "data": { "status": "ok" } }`
- [ ] `SetLocale` middleware reads `Accept-Language` header
- [ ] `ForceJsonResponse` middleware registered for API routes
- [ ] Validation errors return 422 with field-level error messages in JSON

**Relevant DB Tables**: None

**API Endpoints**:

| Method | Path | Description | Request | Response |
|---|---|---|---|---|
| `GET` | `/api/v1/health` | Health check | — | `200 { "success": true, "data": { "status": "ok", "timestamp": "...", "services": { "database": "ok", "redis": "ok", "meilisearch": "ok" } } }` |

---

## Folder / File Structure to Create

At the end of Sprint 1, the monorepo should look like this:

```
barq-wadih-tech/
├── .github/
│   └── workflows/
│       ├── backend.yml
│       ├── frontend.yml
│       └── mobile.yml
├── backend/                           # Laravel 11
│   ├── app/
│   │   ├── Exceptions/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   └── Api/V1/
│   │   │   │       ├── BaseController.php
│   │   │   │       └── HealthController.php
│   │   │   ├── Middleware/
│   │   │   │   ├── SetLocale.php
│   │   │   │   └── ForceJsonResponse.php
│   │   │   └── Resources/            # (empty, ready for Sprint 2)
│   │   ├── Traits/
│   │   │   └── ApiResponses.php
│   │   └── Models/                    # (empty, ready for Sprint 2)
│   ├── routes/
│   │   ├── api.php
│   │   └── api/
│   │       └── v1.php
│   ├── .env.example
│   ├── composer.json
│   └── ...
├── frontend/                          # Next.js 14+
│   ├── src/
│   │   ├── app/
│   │   │   └── [locale]/
│   │   │       ├── layout.tsx
│   │   │       ├── page.tsx
│   │   │       ├── (public)/
│   │   │       ├── (auth)/
│   │   │       └── admin/
│   │   │           └── layout.tsx
│   │   ├── components/
│   │   │   └── ErrorBoundary.tsx
│   │   ├── lib/
│   │   │   ├── api/
│   │   │   │   ├── client.ts
│   │   │   │   ├── types.ts
│   │   │   │   └── endpoints.ts
│   │   │   └── hooks/
│   │   │       └── useApi.ts
│   │   ├── messages/
│   │   │   ├── ar.json
│   │   │   └── en.json
│   │   └── styles/
│   │       ├── globals.css
│   │       └── tokens.css
│   ├── .env.local
│   ├── next.config.js
│   ├── package.json
│   └── ...
├── mobile/                            # Flutter 3.x
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── config/
│   │   │   ├── theme.dart
│   │   │   ├── routes.dart
│   │   │   └── constants.dart
│   │   ├── core/
│   │   │   ├── api/
│   │   │   │   └── api_client.dart
│   │   │   ├── di/
│   │   │   └── utils/
│   │   ├── features/
│   │   │   └── home/
│   │   │       └── home_screen.dart
│   │   ├── l10n/
│   │   │   ├── app_ar.arb
│   │   │   └── app_en.arb
│   │   └── shared/
│   │       ├── widgets/
│   │       └── models/
│   ├── pubspec.yaml
│   └── ...
├── docs/
│   ├── PROJECT_OVERVIEW.md
│   ├── DATABASE_SCHEMA.md
│   ├── SPRINT_LIST.md
│   └── GIT_STRATEGY.md
├── sprints/
│   └── sprint-01.md
├── infra/
│   └── (empty, for deployment scripts later)
├── scripts/
│   ├── dev-up.sh
│   └── dev-down.sh
├── docker-compose.yml
├── .editorconfig
├── .gitignore
├── Makefile
├── README.md
└── CURRENT_STATUS.md
```

---

## Relevant Database Tables

Sprint 1 is infrastructure-only. The only database table created is:

| Table | Source | Purpose |
|---|---|---|
| `personal_access_tokens` | Laravel Sanctum (auto-migration) | Token storage for API authentication — comes with Sanctum install |

All 25 application tables are created in **Sprint 2**.

---

## API Endpoints Summary

| Method | Path | Auth | Description | Request Body | Success Response |
|---|---|---|---|---|---|
| `GET` | `/api/v1/health` | None | System health check | — | `200 { "success": true, "data": { "status": "ok", "timestamp": "...", "services": { "database": "ok", "redis": "ok", "meilisearch": "ok" } } }` |

---

## Definition of "Done"

Sprint 1 is **done** when ALL of the following are true:

1. **Monorepo structure** exists with `backend/`, `frontend/`, `mobile/`, `docs/`, `infra/`, `scripts/` directories
2. **Docker Compose** starts MySQL 8, Redis, and Meilisearch — all three are connectable from the host
3. **Laravel API** runs via `php artisan serve`, connects to Docker MySQL/Redis, and responds to `GET /api/v1/health` with JSON
4. **Laravel base architecture** in place: `BaseController`, `ApiResponses` trait, `ForceJsonResponse` + `SetLocale` middleware, versioned routes, JSON exception handling
5. **Sanctum** installed and configured (migration run, middleware registered)
6. **Next.js frontend** runs via `npm run dev`, renders an Arabic RTL homepage, fetches health check from Laravel
7. **i18n** configured with `next-intl` — Arabic default, English secondary — with `[locale]` routing
8. **Design tokens** defined in CSS custom properties (colors, fonts, spacing)
9. **Flutter app** runs on emulator, shows Arabic RTL layout, Dio client configured
10. **CI/CD** — Three GitHub Actions workflows exist and pass (backend, frontend, mobile)
11. **Git strategy** documented in `docs/GIT_STRATEGY.md`
12. **No hardcoded secrets** — all sensitive values in `.env` files (which are `.gitignore`'d)

---

## Testing Checklist

### Infrastructure
- [ ] `docker compose up -d` → all 3 services start and stay healthy
- [ ] `docker compose down && docker compose up -d` → data persists (MySQL volume)
- [ ] MySQL: `mysql -h 127.0.0.1 -P 3306 -u barq_user -p` → connects successfully
- [ ] Redis: `redis-cli -h 127.0.0.1 ping` → `PONG`
- [ ] Meilisearch: `curl http://localhost:7700/health` → `{"status":"available"}`

### Backend (Laravel)
- [ ] `php artisan serve` → no errors
- [ ] `curl http://localhost:8000/api/v1/health` → `200` JSON with `"success": true`
- [ ] `php artisan migrate` → runs without errors
- [ ] `php artisan migrate:fresh` → drops and re-creates tables
- [ ] Hit a non-existent route → returns JSON 404 (not HTML)
- [ ] Send invalid data to a future validation endpoint → returns JSON 422 (test with health endpoint override or dummy route)
- [ ] `Accept-Language: en` header → app locale set to English
- [ ] `Accept-Language: ar` header → app locale set to Arabic

### Frontend (Next.js)
- [ ] `npm run dev` → starts on `http://localhost:3000`
- [ ] Visit `http://localhost:3000` → redirects to `/ar` (default locale)
- [ ] Page renders with RTL direction (`dir="rtl"`)
- [ ] Visit `http://localhost:3000/en` → page renders LTR
- [ ] Arabic font (IBM Plex Sans Arabic) loads correctly
- [ ] Health check data from API displays on the page
- [ ] `npm run build` → builds without errors
- [ ] `npm run lint` → passes

### Mobile (Flutter)
- [ ] `flutter run` → app launches on emulator
- [ ] App displays Arabic title "برق واضح"
- [ ] Layout is RTL by default
- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → passes (even if only default test)

### CI/CD
- [ ] Push to `develop` → all three workflows trigger
- [ ] Backend workflow → installs, tests, passes
- [ ] Frontend workflow → lints, builds, passes
- [ ] Mobile workflow → analyzes, tests, passes

### Security & Config
- [ ] `.env` files are in `.gitignore`
- [ ] `.env.example` files exist with placeholder values (no real secrets)
- [ ] CORS allows `http://localhost:3000` only
- [ ] API rate limiting is configured (default Laravel throttle)
