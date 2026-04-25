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
   - `laravel/pint` — code formatting (PSR-12 + Laravel preset)
   - `larastan/larastan` — static analysis (PHPStan Level 6)
   - `beyondcode/laravel-query-detector` (dev) — N+1 query detection
4. Run `php artisan migrate` to confirm DB connection (default Laravel tables)
5. Create a health-check endpoint: `GET /api/health` → `{ "status": "ok", "timestamp": "..." }`
6. Configure CORS for `http://localhost:3000` (Next.js dev server)
7. Set `APP_TIMEZONE=Asia/Riyadh`
8. Configure rate limiting per `docs/ARCHITECTURE.md` §7.5 (auth: 5/min, api: 60/min, search: 30/min, upload: 20/hr, ad-create: 10/hr)
9. Create `phpstan.neon` with level 6 + Laravel-specific ignores
10. Create `pint.json` with Laravel preset

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
   - `@tanstack/react-query` — data fetching / server state cache
   - `zustand` — client state management (UI, auth token, filters)
   - `framer-motion` — animations (page transitions, layout, exit)
   - `react-hook-form` + `@hookform/resolvers` — performant forms
   - `zod` — schema validation (shared between client/server validation)
   - `lucide-react` — icon system (tree-shakeable, 1000+ icons)
3. Install dev dependencies:
   - `prettier` + `eslint-config-prettier` — code formatting
   - `@typescript-eslint/eslint-plugin` — strict TS linting
   - Configure ESLint: `no-explicit-any: error`, `import/order: error`
   - Create `.prettierrc` per `docs/ARCHITECTURE.md` §5.3
4. Set up i18n:
   - Create `frontend/src/messages/ar.json` with basic keys (`app.name`, `app.description`, `common.loading`, etc.)
   - Create `frontend/src/messages/en.json` with same keys
   - Configure `next-intl` middleware for `[locale]` routing (default: `ar`)
5. Create **full design system** from `docs/ARCHITECTURE.md` §4:
   - `frontend/src/styles/tokens.css` — ALL design tokens (colors, spacing, typography, shadows, radius, transitions) including dark mode overrides via `prefers-color-scheme`
   - `frontend/src/styles/globals.css` — CSS reset, base styles, global utility classes, keyframe animations (fadeIn, shimmer, slideUp, scaleIn)
   - `frontend/src/styles/animations.css` — reusable animation keyframes
   - Import Google Fonts: **IBM Plex Sans Arabic** (Arabic) + **Inter** (English/numerals)
   - Use CSS logical properties throughout (margin-inline-start, NOT margin-left)
6. Create UI primitive components (see `docs/ARCHITECTURE.md` §2.2):
   - `components/ui/Button/` — primary, secondary, ghost, danger variants + sizes (sm, md, lg) + loading state
   - `components/ui/Input/` — text, number, textarea with label, error, RTL support
   - `components/ui/Card/` — with hover shadow transition
   - `components/ui/Badge/` — status variants (active, sold, expired, verified)
   - `components/ui/Skeleton/` — shimmer loading placeholder
   - `components/ui/Toast/` — success, error, warning, info with slide animation
   - `components/ui/Avatar/` — with fallback initials
   - `components/ui/EmptyState/` — illustrated with CTA
   - Each component: `.tsx` + `.module.css` + `index.ts` barrel export
7. Set up routing structure:
   ```
   src/app/
   ├── [locale]/
   │   ├── layout.tsx          # RTL/LTR wrapper, font loading, providers
   │   ├── page.tsx            # Homepage placeholder
   │   ├── not-found.tsx       # Styled 404 page
   │   ├── error.tsx           # Error boundary
   │   ├── loading.tsx         # Suspense fallback with skeleton
   │   ├── (public)/           # Public pages (future: ads, search)
   │   ├── (auth)/             # Auth pages (future: login, register)
   │   │   └── layout.tsx      # Auth layout (no header/footer)
   │   ├── (dashboard)/        # Authenticated user pages
   │   │   └── layout.tsx      # Dashboard layout
   │   └── admin/              # Admin panel (future)
   │       └── layout.tsx      # Admin layout placeholder
   ```
8. Create provider wrappers:
   - `components/providers/QueryProvider.tsx` — TanStack Query provider
   - `components/providers/ThemeProvider.tsx` — dark mode toggle support
9. Create a minimal homepage that fetches `/api/health` from Laravel and displays it using the new UI components
10. Configure `next.config.js` for `images.remotePatterns` (DO Spaces domain)

**Acceptance Criteria**:
- [ ] `npm run dev` starts on `http://localhost:3000` without errors
- [ ] Homepage renders in Arabic (RTL direction) by default
- [ ] Visiting `/en` switches to English (LTR direction)
- [ ] **Full design tokens** defined in `tokens.css` — all colors, spacing, typography, shadows, radius, transitions (per ARCHITECTURE.md §4)
- [ ] **Dark mode** works via `prefers-color-scheme` — semantic tokens swap correctly
- [ ] IBM Plex Sans Arabic font loads for Arabic text, Inter for English
- [ ] Homepage successfully fetches and displays health check from Laravel API
- [ ] Route group structure exists: `(public)`, `(auth)`, `(dashboard)`, `admin` with `not-found.tsx`, `error.tsx`, `loading.tsx`
- [ ] **UI primitives exist**: Button, Input, Card, Badge, Skeleton, Toast, Avatar, EmptyState — all with CSS Modules
- [ ] All CSS uses logical properties (`margin-inline-start`, NOT `margin-left`)
- [ ] ESLint passes with `no-explicit-any: error`
- [ ] Prettier formatting applied
- [ ] No Tailwind — only vanilla CSS + CSS Modules
- [ ] `npm run build` succeeds with zero warnings

**Relevant DB Tables**: None

**API Endpoints**: Consumes `GET /api/health` (built in Task 3)

---

### Task 5 — Flutter Mobile Scaffold

**Description**: Initialize a Flutter project inside `mobile/`, set up the project structure, configure dependencies, and create a minimal working app.

**Steps**:
1. Run `flutter create --org com.barqwadih mobile` (or `flutter create` inside `mobile/`)
2. Set up project structure per `docs/ARCHITECTURE.md` §3.2 (Feature-First Clean Architecture):
   ```
   mobile/lib/
   ├── main.dart
   ├── app.dart                    # MaterialApp.router configuration
   ├── bootstrap.dart              # DI setup, error handling, init
   ├── config/
   │   ├── theme/
   │   │   ├── app_theme.dart      # ThemeData builder (light + dark)
   │   │   ├── app_colors.dart     # Color palette matching web tokens
   │   │   ├── app_typography.dart  # TextStyle definitions
   │   │   ├── app_spacing.dart    # EdgeInsets, gaps, padding constants
   │   │   ├── app_shadows.dart    # BoxShadow presets
   │   │   └── app_radius.dart     # BorderRadius presets
   │   ├── env/
   │   │   └── env_config.dart     # Environment-specific config
   │   └── routes/
   │       ├── app_router.dart     # GoRouter config
   │       └── route_names.dart    # Named route constants
   ├── core/
   │   ├── api/
   │   │   ├── api_client.dart     # Dio singleton + interceptors
   │   │   ├── api_exceptions.dart # Typed API error classes
   │   │   ├── api_response.dart   # Generic response wrapper
   │   │   └── interceptors/
   │   │       ├── auth_interceptor.dart
   │   │       ├── locale_interceptor.dart
   │   │       └── error_interceptor.dart
   │   ├── extensions/
   │   │   ├── context_extensions.dart
   │   │   └── string_extensions.dart
   │   └── utils/
   │       ├── formatters.dart     # Currency (SAR), date, phone
   │       └── validators.dart
   ├── features/                   # Feature-first (data/domain/presentation per feature)
   │   └── home/
   │       └── presentation/
   │           └── screens/
   │               └── home_screen.dart
   ├── l10n/
   │   ├── app_ar.arb
   │   └── app_en.arb
   └── shared/
       ├── widgets/
       │   ├── buttons/
       │   │   ├── primary_button.dart
       │   │   └── secondary_button.dart
       │   ├── inputs/
       │   │   └── app_text_field.dart
       │   ├── cards/
       │   │   └── base_card.dart
       │   ├── feedback/
       │   │   ├── shimmer_loading.dart
       │   │   ├── empty_state.dart
       │   │   └── error_view.dart
       │   └── layout/
       │       ├── app_scaffold.dart
       │       └── bottom_nav_bar.dart  # 5-tab with center FAB
       └── models/
           ├── pagination_meta.dart
           └── api_error.dart
   ```
3. Install core packages in `pubspec.yaml`:
   - `dio` — HTTP client with interceptors
   - `flutter_riverpod` — state management (compile-safe, testable)
   - `go_router` — declarative navigation + deep linking
   - `flutter_localizations` + `intl` — i18n
   - `cached_network_image` — image caching with placeholder
   - `flutter_secure_storage` — encrypted token storage
   - `google_fonts` — IBM Plex Sans Arabic + Inter
   - `iconsax_flutter` — premium icon set (outline, bold, bulk variants)
   - `flutter_animate` — declarative staggered/spring animations
   - `shimmer` — skeleton loading effects
   - `hive_flutter` + `hive` — fast local KV cache
   - `json_annotation` + `json_serializable` + `build_runner` (dev) — type-safe JSON codegen
   - `flutter_form_builder` + `form_builder_validators` — declarative forms
4. Configure **premium Arabic-first theme** (per ARCHITECTURE.md §3.3):
   - Default locale: `ar`, RTL text direction
   - **Light + Dark ThemeData** using color palette matching web tokens
   - Custom `TextTheme` with IBM Plex Sans Arabic (6 weights)
   - Card theme: 16px radius, subtle shadows, generous padding
   - Bottom nav: floating style, Iconsax outline (inactive) / bold (active)
   - App bar: transparent/blur effect, no elevation
   - Input decoration: outlined with rounded borders, focus color
5. Create **shared UI widgets** (premium, reusable):
   - `PrimaryButton` / `SecondaryButton` with loading state + scale animation on press
   - `AppTextField` with RTL label, error state, prefix/suffix icons
   - `BaseCard` with hover shadow + rounded corners
   - `ShimmerLoading` matching card layout dimensions
   - `EmptyState` with illustration placeholder + CTA button
   - `BottomNavBar` 5-tab (Home, Search, +Post, Chat, Profile) with center FAB
6. Create `ApiClient` with Dio configured for:
   - Base URL: `http://10.0.2.2:8000/api` (Android emulator → host)
   - Accept: `application/json`
   - Auth interceptor: inject Sanctum token from secure storage
   - Locale interceptor: inject Accept-Language from app locale
   - Error interceptor: map HTTP errors to typed `ApiException` classes
7. Configure `analysis_options.yaml` with pedantic lint rules (per ARCHITECTURE.md §5.1)
8. Test: app launches, shows Arabic "برق واضح" title, calls health check, dark mode toggles correctly

**Acceptance Criteria**:
- [ ] `flutter run` launches the app on emulator/simulator without errors
- [ ] App displays in Arabic with RTL layout by default
- [ ] **Dark mode** works — toggle between light/dark themes
- [ ] Dio `ApiClient` configured with auth, locale, and error interceptors
- [ ] Project structure matches feature-first clean architecture (data/domain/presentation per feature)
- [ ] Localization files (`app_ar.arb`, `app_en.arb`) exist with basic keys
- [ ] Brand theme applied: colors match web tokens, IBM Plex Sans Arabic loaded, card radius 16px
- [ ] **Shared widgets exist**: PrimaryButton, AppTextField, BaseCard, ShimmerLoading, EmptyState, BottomNavBar
- [ ] Bottom navigation shows 5 tabs with center FAB for "Post Ad"
- [ ] Iconsax icons used (outline inactive, bold active)
- [ ] `flutter analyze` passes with zero issues (pedantic rules)
- [ ] Staggered fade-in animation on home screen list items

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

### Task 7 — CI/CD Pipeline + Code Quality Hooks

**Description**: Set up GitHub Actions workflows for automated linting, testing, and deployment preparation. Set up local Git hooks for pre-commit formatting and conventional commit enforcement.

**Steps**:
1. Create `.github/workflows/backend.yml`:
   - Trigger: push/PR to `main` and `develop` branches
   - Matrix: PHP 8.3
   - Steps: checkout → composer install → copy `.env.testing` → `php artisan test` → Larastan level 6 → Pint (check mode)
   - Services: MySQL 8 (GitHub Actions service container)
2. Create `.github/workflows/frontend.yml`:
   - Trigger: push/PR to `main` and `develop`
   - Steps: checkout → npm ci → `npm run lint` → Prettier check → `npm run build` → `npm run test` (if tests exist)
3. Create `.github/workflows/mobile.yml`:
   - Trigger: push/PR to `main` and `develop`
   - Steps: checkout → Flutter setup → `flutter analyze` → `dart format --set-exit-if-changed .` → `flutter test`
4. **Set up Husky + lint-staged** at monorepo root:
   - Install `husky`, `lint-staged`, `@commitlint/cli`, `@commitlint/config-conventional`
   - Pre-commit hook: run `lint-staged` (Prettier + ESLint on staged frontend files, Pint on staged PHP files, dart format on staged Dart files)
   - Commit-msg hook: run `commitlint` to enforce conventional commits (per ARCHITECTURE.md §5.5)
5. Create `.commitlintrc.json` with conventional commit config
6. Create `.lintstagedrc.json` with per-stack formatting rules
7. Create `PULL_REQUEST_TEMPLATE.md` in `.github/` with the PR checklist from ARCHITECTURE.md §5.6
8. Create branch protection rules documentation (in `docs/`):
   - `main`: requires PR + CI pass
   - `develop`: working branch
9. Create git branching strategy doc: `docs/GIT_STRATEGY.md`
   - Feature branches: `feature/sprint-XX-description`
   - Bugfix branches: `fix/description`
   - Release branches: `release/vX.Y.Z`
   - Conventional commits enforced via commitlint

**Acceptance Criteria**:
- [ ] Push to `develop` triggers all three CI workflows
- [ ] Backend workflow: installs deps, runs tests, passes Larastan level 6, Pint check passes
- [ ] Frontend workflow: lints (zero `any` errors), Prettier check, builds successfully
- [ ] Mobile workflow: analyzes (pedantic), format check, tests
- [ ] **Husky pre-commit hook** runs lint-staged on commit
- [ ] **Commitlint** rejects non-conventional commit messages (e.g. `fixed stuff` rejected, `fix(backend): resolve auth bug` accepted)
- [ ] PR template includes full checklist from ARCHITECTURE.md
- [ ] `docs/GIT_STRATEGY.md` documents branching strategy
- [ ] All workflows use caching (Composer cache, npm cache, Flutter pub cache)

---

### Task 8 — Laravel API Structure & Base Classes

**Description**: Set up the full Laravel API architecture per `docs/ARCHITECTURE.md` §1 — layered architecture with controllers, services, actions, DTOs, enums, events, and middleware — so Sprint 2+ can follow a consistent pattern.

**Steps**:
1. Create `app/Http/Controllers/Api/V1/BaseController.php`:
   - Standard JSON response helpers: `successResponse()`, `errorResponse()`, `paginatedResponse()`
   - Response format per ARCHITECTURE.md §1.5
2. Create `app/Traits/ApiResponses.php` trait (used by BaseController)
3. Create `app/Traits/HasSlug.php` trait (auto-generate slugs on models)
4. Create `app/Traits/Filterable.php` trait (query filter scopes)
5. Create `app/Exceptions/Handler.php` customization:
   - All exceptions return JSON (no HTML for API)
   - Validation: 422 with field errors
   - Auth: 401
   - Not found: 404
   - Rate limit: 429
   - Server error: 500 (hide details in production)
6. Create custom exception classes:
   - `app/Exceptions/AdNotFoundException.php`
   - `app/Exceptions/InsufficientPermissionException.php`
   - `app/Exceptions/PaymentFailedException.php`
7. Create directory scaffolding for the layered architecture (empty directories with `.gitkeep`):
   - `app/Actions/Ad/`, `app/Actions/Commission/`, `app/Actions/User/`
   - `app/DTOs/`
   - `app/Services/`
   - `app/Events/Ad/`, `app/Events/Commission/`, `app/Events/User/`
   - `app/Listeners/Ad/`, `app/Listeners/Commission/`, `app/Listeners/User/`
   - `app/Observers/`
   - `app/Http/Requests/Ad/`, `app/Http/Requests/Auth/`
   - `app/Http/Resources/`
8. Create PHP 8.1 Enums:
   - `app/Enums/AdStatus.php` — active, sold, expired, pending_review, rejected, deleted
   - `app/Enums/ModerationStatus.php` — approved, flagged, under_review, rejected
   - `app/Enums/CommissionStatus.php` — not_applicable, pending, paid
   - `app/Enums/UserRole.php` — user, admin, super_admin
   - `app/Enums/ReportReason.php` — fake, spam, prohibited_content, etc.
   - `app/Enums/PaymentMethod.php` — card, mada, sadad, apple_pay, bank_transfer
9. Set up route versioning:
   - `routes/api.php` → includes `routes/api/v1.php`
   - All v1 routes prefixed with `/api/v1/`
   - Move health check to `/api/v1/health`
10. Create `app/Http/Middleware/SetLocale.php`:
    - Read `Accept-Language` header or `?lang=` param
    - Set app locale to `ar` or `en`
11. Create `app/Http/Middleware/ForceJsonResponse.php`:
    - Ensure all API responses are JSON
12. Register middleware in `bootstrap/app.php`
13. Register rate limiters per ARCHITECTURE.md §7.5 in `bootstrap/app.php`

**Acceptance Criteria**:
- [ ] `BaseController` with `successResponse()` and `errorResponse()` helpers
- [ ] All API exceptions return consistent JSON format (no HTML stack traces)
- [ ] Custom exception classes exist and auto-map to correct HTTP status codes
- [ ] **Layered architecture directories scaffolded**: Actions, DTOs, Services, Events, Listeners, Observers, Enums
- [ ] **6 PHP Enums** created (AdStatus, ModerationStatus, CommissionStatus, UserRole, ReportReason, PaymentMethod)
- [ ] Traits created: ApiResponses, HasSlug, Filterable
- [ ] Routes versioned under `/api/v1/`
- [ ] `GET /api/v1/health` works with new response format: `{ "success": true, "data": { "status": "ok" } }`
- [ ] `SetLocale` middleware reads `Accept-Language` header
- [ ] `ForceJsonResponse` middleware registered for API routes
- [ ] Validation errors return 422 with field-level error messages in JSON
| Method | Path | Description | Request | Response |
|---|---|---|---|---|
| `GET` | `/api/v1/health` | Health check | — | `200 { "success": true, "data": { "status": "ok", "timestamp": "...", "services": { "database": "ok", "redis": "ok", "meilisearch": "ok" } } }` |

---

## Folder / File Structure to Create

At the end of Sprint 1, the monorepo should look like this:

```
barq-wadih-tech/
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md       # PR checklist from ARCHITECTURE.md
│   └── workflows/
│       ├── backend.yml
│       ├── frontend.yml
│       └── mobile.yml
├── .commitlintrc.json                 # Conventional commits config
├── .lintstagedrc.json                 # Per-stack formatting rules
├── .husky/                            # Git hooks
│   ├── pre-commit                     # lint-staged
│   └── commit-msg                     # commitlint
├── backend/                           # Laravel 11
│   ├── app/
│   │   ├── Actions/                   # Single-purpose operations
│   │   │   ├── Ad/.gitkeep
│   │   │   ├── Commission/.gitkeep
│   │   │   └── User/.gitkeep
│   │   ├── DTOs/.gitkeep              # Data Transfer Objects
│   │   ├── Enums/                     # PHP 8.1 Enums
│   │   │   ├── AdStatus.php
│   │   │   ├── ModerationStatus.php
│   │   │   ├── CommissionStatus.php
│   │   │   ├── UserRole.php
│   │   │   ├── ReportReason.php
│   │   │   └── PaymentMethod.php
│   │   ├── Events/                    # Domain events
│   │   │   ├── Ad/.gitkeep
│   │   │   ├── Commission/.gitkeep
│   │   │   └── User/.gitkeep
│   │   ├── Exceptions/
│   │   │   ├── AdNotFoundException.php
│   │   │   ├── InsufficientPermissionException.php
│   │   │   └── PaymentFailedException.php
│   │   ├── Http/
│   │   │   ├── Controllers/Api/V1/
│   │   │   │   ├── BaseController.php
│   │   │   │   └── HealthController.php
│   │   │   ├── Middleware/
│   │   │   │   ├── SetLocale.php
│   │   │   │   └── ForceJsonResponse.php
│   │   │   ├── Requests/              # FormRequest validation
│   │   │   │   ├── Ad/.gitkeep
│   │   │   │   └── Auth/.gitkeep
│   │   │   └── Resources/.gitkeep     # API Resources
│   │   ├── Listeners/                 # Event listeners
│   │   │   ├── Ad/.gitkeep
│   │   │   ├── Commission/.gitkeep
│   │   │   └── User/.gitkeep
│   │   ├── Models/                    # (empty, ready for Sprint 2)
│   │   ├── Observers/.gitkeep         # Model observers
│   │   ├── Services/.gitkeep          # Business logic services
│   │   └── Traits/
│   │       ├── ApiResponses.php
│   │       ├── HasSlug.php
│   │       └── Filterable.php
│   ├── routes/
│   │   ├── api.php
│   │   └── api/v1.php
│   ├── phpstan.neon                   # Larastan Level 6
│   ├── pint.json                      # Laravel Pint config
│   ├── .env.example
│   ├── composer.json
│   └── ...
├── frontend/                          # Next.js 14+
│   ├── src/
│   │   ├── app/
│   │   │   └── [locale]/
│   │   │       ├── layout.tsx         # RTL/LTR, fonts, providers
│   │   │       ├── page.tsx           # Homepage
│   │   │       ├── not-found.tsx      # Styled 404
│   │   │       ├── error.tsx          # Error boundary
│   │   │       ├── loading.tsx        # Suspense fallback
│   │   │       ├── (public)/
│   │   │       ├── (auth)/
│   │   │       │   └── layout.tsx
│   │   │       ├── (dashboard)/
│   │   │       │   └── layout.tsx
│   │   │       └── admin/
│   │   │           └── layout.tsx
│   │   ├── components/
│   │   │   ├── ui/                    # Design system primitives
│   │   │   │   ├── Button/
│   │   │   │   ├── Input/
│   │   │   │   ├── Card/
│   │   │   │   ├── Badge/
│   │   │   │   ├── Skeleton/
│   │   │   │   ├── Toast/
│   │   │   │   ├── Avatar/
│   │   │   │   └── EmptyState/
│   │   │   ├── layout/
│   │   │   └── providers/
│   │   │       ├── QueryProvider.tsx
│   │   │       └── ThemeProvider.tsx
│   │   ├── hooks/
│   │   ├── lib/
│   │   │   ├── api/
│   │   │   │   ├── client.ts
│   │   │   │   ├── types.ts
│   │   │   │   └── endpoints.ts
│   │   │   ├── stores/                # Zustand stores
│   │   │   └── utils/
│   │   ├── messages/
│   │   │   ├── ar.json
│   │   │   └── en.json
│   │   ├── styles/
│   │   │   ├── globals.css
│   │   │   ├── tokens.css             # Full design tokens + dark mode
│   │   │   └── animations.css
│   │   └── types/
│   ├── .env.local
│   ├── .prettierrc
│   ├── next.config.js
│   ├── package.json
│   └── ...
├── mobile/                            # Flutter 3.x
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart                   # MaterialApp.router
│   │   ├── bootstrap.dart             # DI, error handling, init
│   │   ├── config/
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart     # Light + Dark ThemeData
│   │   │   │   ├── app_colors.dart
│   │   │   │   ├── app_typography.dart
│   │   │   │   ├── app_spacing.dart
│   │   │   │   ├── app_shadows.dart
│   │   │   │   └── app_radius.dart
│   │   │   ├── env/env_config.dart
│   │   │   └── routes/
│   │   │       ├── app_router.dart    # GoRouter
│   │   │       └── route_names.dart
│   │   ├── core/
│   │   │   ├── api/
│   │   │   │   ├── api_client.dart    # Dio + interceptors
│   │   │   │   ├── api_exceptions.dart
│   │   │   │   ├── api_response.dart
│   │   │   │   └── interceptors/
│   │   │   │       ├── auth_interceptor.dart
│   │   │   │       ├── locale_interceptor.dart
│   │   │   │       └── error_interceptor.dart
│   │   │   ├── extensions/
│   │   │   └── utils/
│   │   ├── features/
│   │   │   └── home/
│   │   │       └── presentation/screens/home_screen.dart
│   │   ├── l10n/
│   │   │   ├── app_ar.arb
│   │   │   └── app_en.arb
│   │   └── shared/
│   │       ├── widgets/
│   │       │   ├── buttons/           # PrimaryButton, SecondaryButton
│   │       │   ├── inputs/            # AppTextField
│   │       │   ├── cards/             # BaseCard
│   │       │   ├── feedback/          # ShimmerLoading, EmptyState, ErrorView
│   │       │   └── layout/            # AppScaffold, BottomNavBar
│   │       └── models/
│   ├── analysis_options.yaml          # Pedantic lint rules
│   ├── pubspec.yaml
│   └── ...
├── docs/
│   ├── PROJECT_OVERVIEW.md
│   ├── DATABASE_SCHEMA.md
│   ├── SPRINT_LIST.md
│   ├── ARCHITECTURE.md                # ★ NEW — full architecture standards
│   ├── DECISIONS_LOG.md               # ★ NEW — stack decisions log
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
4. **Laravel architecture scaffolded**: BaseController, Traits (ApiResponses, HasSlug, Filterable), 6 Enums, custom exceptions, middleware (ForceJsonResponse, SetLocale), versioned routes, layered directory structure (Actions, DTOs, Services, Events, Listeners, Observers)
5. **Sanctum** installed and configured (migration run, middleware registered)
6. **Larastan** Level 6 configured and passing, **Pint** configured with Laravel preset
7. **Next.js frontend** runs via `npm run dev`, renders an Arabic RTL homepage, fetches health check from Laravel
8. **i18n** configured with `next-intl` — Arabic default, English secondary — with `[locale]` routing
9. **Full design tokens** defined in `tokens.css` — all colors (light + dark), spacing, typography, shadows, radius, transitions per ARCHITECTURE.md §4
10. **UI primitive components** exist: Button, Input, Card, Badge, Skeleton, Toast, Avatar, EmptyState — all with CSS Modules
11. **Dark mode** works across web (prefers-color-scheme) and mobile (ThemeData)
12. **Flutter app** runs on emulator, shows Arabic RTL layout, premium theme, Dio client with auth/locale/error interceptors, shared widgets, BottomNavBar with center FAB, Iconsax icons
13. **CI/CD** — Three GitHub Actions workflows exist and pass (backend with Larastan, frontend with ESLint+Prettier, mobile with pedantic analyze)
14. **Code quality hooks** — Husky pre-commit (lint-staged), commitlint (conventional commits)
15. **PR template** with full checklist from ARCHITECTURE.md
16. **Git strategy** documented in `docs/GIT_STRATEGY.md`
17. **Architecture & Decisions** documented in `docs/ARCHITECTURE.md` and `docs/DECISIONS_LOG.md`
18. **No hardcoded secrets** — all sensitive values in `.env` files (which are `.gitignore`'d)

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
- [ ] Send invalid data → returns JSON 422 with field-level errors
- [ ] `Accept-Language: en` header → app locale set to English
- [ ] `Accept-Language: ar` header → app locale set to Arabic
- [ ] `./vendor/bin/phpstan analyse` → passes at level 6
- [ ] `./vendor/bin/pint --test` → passes (code is formatted)
- [ ] All 6 Enums instantiate correctly
- [ ] Rate limiters registered (test with rapid requests)

### Frontend (Next.js)
- [ ] `npm run dev` → starts on `http://localhost:3000`
- [ ] Visit `http://localhost:3000` → redirects to `/ar` (default locale)
- [ ] Page renders with RTL direction (`dir="rtl"`)
- [ ] Visit `http://localhost:3000/en` → page renders LTR
- [ ] Arabic font (IBM Plex Sans Arabic) loads correctly
- [ ] Health check data from API displays on the page
- [ ] **Dark mode**: toggle system appearance → tokens swap correctly
- [ ] **UI primitives**: Button renders all 4 variants, Input shows error state, Card has hover shadow, Skeleton shimmers
- [ ] All CSS uses logical properties (inspect with dev tools — no `left`/`right`)
- [ ] `npm run build` → builds without errors or warnings
- [ ] `npm run lint` → passes with zero `any` errors
- [ ] Visit `/ar/nonexistent` → styled 404 page renders

### Mobile (Flutter)
- [ ] `flutter run` → app launches on emulator
- [ ] App displays Arabic title "برق واضح"
- [ ] Layout is RTL by default
- [ ] **Dark mode**: toggle → light/dark themes switch
- [ ] **Bottom nav** shows 5 tabs with center FAB (+)
- [ ] Iconsax icons render (outline inactive, bold active)
- [ ] SharedWidgets: PrimaryButton shows loading spinner, AppTextField shows error state
- [ ] `flutter analyze` → zero issues (pedantic)
- [ ] `flutter test` → passes (even if only default test)

### Code Quality
- [ ] `git commit -m "bad message"` → rejected by commitlint
- [ ] `git commit -m "feat(backend): test"` → accepted by commitlint
- [ ] Pre-commit hook runs and auto-formats staged files
- [ ] PR template appears when opening PR on GitHub

### Security & Config
- [ ] `.env` files are in `.gitignore`
- [ ] `.env.example` files exist with placeholder values (no real secrets)
- [ ] CORS allows `http://localhost:3000` only
- [ ] Rate limiters registered: auth (5/min), api (60/min), search (30/min), upload (20/hr), ad-create (10/hr)
