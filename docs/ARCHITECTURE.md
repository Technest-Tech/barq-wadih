# Barq Wadih — Architecture & Engineering Standards

> **Version**: 1.0 · **Last Updated**: 2026-04-08
>
> This document is the single source of truth for architecture patterns, design system, code quality, testing, and scalability. Every contributor must follow these standards.

---

## Table of Contents

1. [Backend Architecture (Laravel)](#1-backend-architecture-laravel)
2. [Frontend Architecture (Next.js)](#2-frontend-architecture-nextjs)
3. [Mobile Architecture (Flutter)](#3-mobile-architecture-flutter)
4. [Design System](#4-design-system)
5. [Code Quality Guardrails](#5-code-quality-guardrails)
6. [Testing Strategy](#6-testing-strategy)
7. [Scalability Patterns](#7-scalability-patterns)
8. [Readability Standards](#8-readability-standards)

---

## 1. Backend Architecture (Laravel)

### 1.1 Layered Architecture

```
HTTP Request
    │
    ▼
┌─────────────────────┐
│   Middleware         │  ForceJsonResponse, SetLocale, RateLimit, Sanctum
├─────────────────────┤
│   Controller        │  Validate input (FormRequest), delegate, return response
├─────────────────────┤
│   FormRequest       │  All validation rules — NEVER validate in controllers
├─────────────────────┤
│   Service           │  Business logic lives HERE (AdService, CommissionService)
├─────────────────────┤
│   Action (optional) │  Single-purpose operations (DeclareAdSaleAction)
├─────────────────────┤
│   Repository (opt.) │  Complex query logic, scopes, search
├─────────────────────┤
│   Model + Scopes    │  Eloquent relationships, accessors, scopes
├─────────────────────┤
│   Event → Listener  │  Decoupled side-effects (async via queue)
├─────────────────────┤
│   Job               │  Heavy/async work (images, notifications, indexing)
└─────────────────────┘
```

### 1.2 Directory Structure

```
backend/app/
├── Actions/                    # Single-purpose business operations
│   ├── Ad/
│   │   ├── CreateAdAction.php
│   │   ├── DeclareAdSaleAction.php
│   │   └── ExpireAdsAction.php
│   ├── Commission/
│   │   └── CalculateCommissionAction.php
│   └── User/
│       └── GrantVerifiedBadgeAction.php
├── DTOs/                       # Data Transfer Objects (typed value objects)
│   ├── AdData.php
│   ├── PaginationData.php
│   └── UserData.php
├── Enums/                      # PHP 8.1 Enums
│   ├── AdStatus.php
│   ├── CommissionStatus.php
│   ├── ModerationStatus.php
│   ├── PaymentMethod.php
│   ├── ReportReason.php
│   └── UserRole.php
├── Events/
│   ├── Ad/
│   │   ├── AdCreated.php
│   │   ├── AdSold.php
│   │   └── AdExpired.php
│   ├── Commission/
│   │   └── CommissionPaid.php
│   └── User/
│       └── UserRated.php
├── Exceptions/
│   ├── Handler.php             # Global JSON exception handler
│   ├── AdNotFoundException.php
│   ├── InsufficientPermissionException.php
│   └── PaymentFailedException.php
├── Http/
│   ├── Controllers/Api/V1/
│   │   ├── BaseController.php
│   │   ├── HealthController.php
│   │   ├── AuthController.php
│   │   ├── AdController.php
│   │   ├── CategoryController.php
│   │   └── ...
│   ├── Middleware/
│   │   ├── ForceJsonResponse.php
│   │   ├── SetLocale.php
│   │   └── EnsureAdOwner.php
│   ├── Requests/               # FormRequest classes (validation)
│   │   ├── Ad/
│   │   │   ├── StoreAdRequest.php
│   │   │   └── UpdateAdRequest.php
│   │   └── Auth/
│   │       ├── LoginRequest.php
│   │       └── RegisterRequest.php
│   └── Resources/              # API Resources (response transformation)
│       ├── AdResource.php
│       ├── AdCollection.php
│       ├── CategoryResource.php
│       └── UserResource.php
├── Jobs/
│   ├── ProcessAdImages.php
│   ├── SendPushNotification.php
│   ├── SyncAdToMeilisearch.php
│   └── ExpireOldAds.php
├── Listeners/
│   ├── Ad/
│   │   ├── IndexAdInSearch.php
│   │   ├── IncrementCategoryCounter.php
│   │   └── NotifyCategoryFollowers.php
│   ├── Commission/
│   │   └── GrantVerifiedBadgeOnPayment.php
│   └── User/
│       └── RecalculateUserRating.php
├── Models/
│   ├── Ad.php
│   ├── Category.php
│   ├── User.php
│   └── ...
├── Notifications/              # Laravel notification classes
│   ├── AdExpiringNotification.php
│   └── NewAdInCategoryNotification.php
├── Observers/                  # Model observers for lifecycle hooks
│   ├── AdObserver.php
│   └── UserObserver.php
├── Services/                   # Business logic services
│   ├── AdService.php
│   ├── AuthService.php
│   ├── CategoryService.php
│   ├── CommissionService.php
│   ├── NotificationService.php
│   ├── SearchService.php
│   └── UploadService.php
└── Traits/
    ├── ApiResponses.php
    ├── HasSlug.php
    └── Filterable.php
```

### 1.3 Rules

| Rule | Detail |
|---|---|
| **No business logic in controllers** | Controllers only: validate → delegate to Service/Action → return Resource |
| **No raw queries** | Use Eloquent with scopes. Raw SQL only for analytics queries. |
| **Always eager load** | Every query with relationships MUST use `with()`. No lazy loading. |
| **Always paginate** | No `::all()`. Every list endpoint uses `->paginate()` or `->cursorPaginate()`. |
| **Use Enums** | PHP 8.1 backed enums for all status fields. No magic strings. |
| **Use DTOs** | Pass structured data between layers, not arrays. |
| **Use API Resources** | Never return models directly. Always wrap in `JsonResource`. |
| **Use FormRequests** | One FormRequest per endpoint. Validation logic never in controllers. |
| **Events for side-effects** | Cross-cutting concerns (search indexing, counters, notifications) use Events. |

### 1.4 Event Map

```
AdCreated      → IndexAdInSearch, IncrementCategoryCounter, NotifyCategoryFollowers
AdUpdated      → ReindexAdInSearch
AdSold         → CalculateCommission, UpdateUserStats, DecrementCategoryCounter
AdExpired      → SendExpiryNotification, DecrementCategoryCounter, RemoveFromSearch
AdDeleted      → RemoveFromSearch, DecrementCategoryCounter
UserRated      → RecalculateAvgRating, CheckVerifiedBadgeEligibility
CommissionPaid → GrantVerifiedBadge, SendPaymentConfirmation
ReportCreated  → NotifyAdminTeam, FlagAdForReview
```

### 1.5 API Response Envelope

```json
// Success
{
  "success": true,
  "message": "Ad created successfully",
  "data": { ... },
  "meta": { "current_page": 1, "last_page": 5, "per_page": 20, "total": 98 }
}

// Error
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "title": ["The title field is required."],
    "city_id": ["The selected city is invalid."]
  }
}
```

---

## 2. Frontend Architecture (Next.js)

### 2.1 Stack Decisions

| Concern | Choice | Rationale |
|---|---|---|
| **Framework** | Next.js 14+ (App Router) | SSR/SSG for SEO on ad pages, RSC for performance |
| **Language** | TypeScript (strict mode) | Zero `any` policy |
| **Styling** | Vanilla CSS + CSS Modules | Full control, no runtime cost, RTL-native |
| **State (server)** | TanStack Query v5 | Cache, dedup, stale-while-revalidate, devtools |
| **State (client)** | Zustand | Lightweight, no boilerplate, TypeScript-native |
| **i18n** | next-intl | App Router native, ICU message format |
| **Forms** | React Hook Form + Zod | Performance (uncontrolled), schema validation |
| **Icons** | Lucide React | Tree-shakeable, consistent, 1000+ icons, MIT |
| **Animations** | Framer Motion | Declarative, layout animations, exit animations |
| **HTTP** | Native fetch (wrapped) | No axios — use built-in with typed wrapper |

### 2.2 Directory Structure

```
frontend/src/
├── app/
│   └── [locale]/
│       ├── layout.tsx              # Root layout: fonts, providers, RTL/LTR
│       ├── page.tsx                # Homepage
│       ├── not-found.tsx           # 404 page
│       ├── error.tsx               # Error boundary
│       ├── loading.tsx             # Suspense fallback
│       ├── (public)/               # Public pages
│       │   ├── ads/
│       │   │   ├── page.tsx        # Ad listing / search results
│       │   │   └── [id]/
│       │   │       └── page.tsx    # Ad detail (SSR for SEO)
│       │   ├── categories/
│       │   │   └── [slug]/
│       │   │       └── page.tsx
│       │   └── user/
│       │       └── [id]/
│       │           └── page.tsx    # Public user profile
│       ├── (auth)/                 # Auth pages (no header/footer)
│       │   ├── layout.tsx
│       │   ├── login/page.tsx
│       │   └── register/page.tsx
│       ├── (dashboard)/            # Authenticated user pages
│       │   ├── layout.tsx
│       │   ├── my-ads/page.tsx
│       │   ├── favorites/page.tsx
│       │   ├── chats/page.tsx
│       │   └── settings/page.tsx
│       └── admin/                  # Admin panel
│           ├── layout.tsx
│           ├── page.tsx            # Dashboard
│           ├── users/page.tsx
│           ├── ads/page.tsx
│           └── ...
├── components/
│   ├── ui/                         # Primitive design system components
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   ├── Button.module.css
│   │   │   └── index.ts
│   │   ├── Input/
│   │   ├── Card/
│   │   ├── Badge/
│   │   ├── Modal/
│   │   ├── Drawer/
│   │   ├── Avatar/
│   │   ├── Skeleton/
│   │   ├── Toast/
│   │   ├── Dropdown/
│   │   ├── Tabs/
│   │   └── EmptyState/
│   ├── layout/                     # Structural components
│   │   ├── Header/
│   │   ├── Footer/
│   │   ├── Sidebar/
│   │   ├── Container/
│   │   └── MobileNav/
│   ├── features/                   # Feature-specific composites
│   │   ├── ads/
│   │   │   ├── AdCard/
│   │   │   ├── AdGrid/
│   │   │   ├── AdPostForm/
│   │   │   └── AdImageGallery/
│   │   ├── categories/
│   │   │   ├── CategoryGrid/
│   │   │   └── CategoryTabBar/
│   │   ├── chat/
│   │   │   ├── ChatList/
│   │   │   └── ChatBubble/
│   │   └── search/
│   │       ├── SearchBar/
│   │       └── FilterPanel/
│   └── providers/                  # Context providers
│       ├── QueryProvider.tsx
│       ├── ThemeProvider.tsx
│       └── AuthProvider.tsx
├── hooks/                          # Custom React hooks
│   ├── useAuth.ts
│   ├── useDebounce.ts
│   ├── useMediaQuery.ts
│   ├── useIntersectionObserver.ts
│   └── useLocale.ts
├── lib/
│   ├── api/
│   │   ├── client.ts               # Typed fetch wrapper
│   │   ├── types.ts                # ApiResponse<T>, PaginatedResponse<T>
│   │   ├── endpoints.ts            # Central endpoint registry
│   │   └── queries/                # TanStack Query hooks per domain
│   │       ├── useAds.ts
│   │       ├── useCategories.ts
│   │       └── useAuth.ts
│   ├── utils/
│   │   ├── cn.ts                   # Class name merger utility
│   │   ├── formatters.ts           # Currency, date, number formatters
│   │   └── validators.ts           # Zod schemas
│   ├── constants/
│   │   └── index.ts
│   └── stores/                     # Zustand stores
│       ├── useAuthStore.ts
│       ├── useFilterStore.ts
│       └── useUIStore.ts
├── messages/
│   ├── ar.json
│   └── en.json
├── styles/
│   ├── globals.css                 # Reset, base styles, CSS custom properties
│   ├── tokens.css                  # Design tokens (colors, spacing, typography)
│   └── animations.css              # Keyframe animations
└── types/
    ├── ad.ts
    ├── category.ts
    ├── user.ts
    └── api.ts
```

### 2.3 Naming Conventions

| Item | Convention | Example |
|---|---|---|
| **Components** | PascalCase, folder + index.ts | `components/ui/Button/Button.tsx` |
| **Hooks** | camelCase, `use` prefix | `useAuth.ts`, `useDebounce.ts` |
| **Stores** | camelCase, `use` prefix + `Store` | `useAuthStore.ts` |
| **Utils** | camelCase | `formatCurrency.ts` |
| **Types/Interfaces** | PascalCase, no `I` prefix | `Ad`, `User`, `Category` |
| **CSS Modules** | camelCase classes | `.adCard`, `.priceTag` |
| **Constants** | UPPER_SNAKE_CASE | `API_BASE_URL`, `MAX_IMAGES_PER_AD` |
| **Files** | kebab-case for pages | `my-ads/page.tsx` |
| **Query keys** | array of strings | `['ads', adId]`, `['categories']` |

### 2.4 State Management Rules

```
Server State (TanStack Query)         Client State (Zustand)
─────────────────────────             ─────────────────────
• API data (ads, categories, users)   • Auth token + user session
• Search results                      • UI state (sidebar open, theme)
• Paginated lists                     • Filter selections
• Single resource fetches             • Form draft state

Rule: If data comes from the API → TanStack Query. Everything else → Zustand.
Never duplicate server state in Zustand.
```

### 2.5 Data Fetching Patterns

```typescript
// Server Components (SSR/SSG) — for SEO-critical pages
// app/[locale]/(public)/ads/[id]/page.tsx
async function AdPage({ params }: { params: { id: string } }) {
  const ad = await apiClient.get<Ad>(`/ads/${params.id}`); // server-side fetch
  return <AdDetail ad={ad} />;
}

// Client Components — for interactive/real-time data
// Uses TanStack Query hooks from lib/api/queries/
function AdGrid() {
  const { data, isLoading } = useAds({ category: 'cars', city: 'riyadh' });
  if (isLoading) return <AdGridSkeleton />;
  return <Grid items={data} />;
}
```

---

## 3. Mobile Architecture (Flutter)

### 3.1 Stack Decisions

| Concern | Choice | Rationale |
|---|---|---|
| **Framework** | Flutter 3.x (Dart) | Cross-platform, premium native feel |
| **Architecture** | Feature-first + Clean Architecture layers | Scalable, testable, team-ready |
| **State Management** | Riverpod 2.x | Compile-safe, testable, no context dependency |
| **Navigation** | GoRouter | Declarative, deep linking, type-safe |
| **HTTP** | Dio + Retrofit | Interceptors, type-safe API generation |
| **Local Storage** | flutter_secure_storage (tokens), Hive (cache) | Encrypted tokens, fast KV cache |
| **i18n** | flutter_localizations + intl + ARB | Official, ICU message format |
| **Icons** | Iconsax (Flutter) | Modern, premium icon set (outline + bold + bulk) |
| **Animations** | Flutter built-in + flutter_animate | Staggered, spring, implicit animations |
| **Images** | cached_network_image + shimmer | Cached loading with skeleton placeholders |
| **Forms** | flutter_form_builder + form validators | Declarative, validates on submit |

### 3.2 Directory Structure (Feature-First Clean Architecture)

```
mobile/lib/
├── main.dart                           # Entry point, bootstrap
├── app.dart                            # MaterialApp.router configuration
├── bootstrap.dart                      # DI setup, error handling, init
│
├── core/                               # Shared infrastructure
│   ├── api/
│   │   ├── api_client.dart             # Dio singleton + interceptors
│   │   ├── api_exceptions.dart         # Typed API error classes
│   │   ├── api_response.dart           # Generic response wrapper
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart   # Inject Sanctum token
│   │       ├── locale_interceptor.dart # Inject Accept-Language
│   │       └── error_interceptor.dart  # Map HTTP errors → typed exceptions
│   ├── di/
│   │   └── injection.dart              # Riverpod provider overrides
│   ├── constants/
│   │   ├── api_constants.dart
│   │   ├── app_constants.dart
│   │   └── storage_keys.dart
│   ├── extensions/
│   │   ├── context_extensions.dart     # Theme, locale, navigation shortcuts
│   │   ├── string_extensions.dart
│   │   └── date_extensions.dart
│   ├── router/
│   │   ├── app_router.dart             # GoRouter config
│   │   ├── route_names.dart            # Named route constants
│   │   └── guards/
│   │       └── auth_guard.dart
│   └── utils/
│       ├── formatters.dart             # Currency, date, phone
│       ├── validators.dart             # Form validators
│       └── logger.dart
│
├── config/
│   ├── theme/
│   │   ├── app_theme.dart              # ThemeData builder
│   │   ├── app_colors.dart             # Color palette (light + dark)
│   │   ├── app_typography.dart         # TextStyle definitions
│   │   ├── app_spacing.dart            # EdgeInsets, gaps, padding constants
│   │   ├── app_shadows.dart            # BoxShadow presets
│   │   └── app_radius.dart             # BorderRadius presets
│   └── env/
│       ├── env_config.dart             # Environment variables
│       └── flavors.dart                # dev / staging / production
│
├── l10n/
│   ├── app_ar.arb                      # Arabic strings (primary)
│   ├── app_en.arb                      # English strings
│   └── l10n.dart                       # Generated localization delegate
│
├── shared/                             # Shared across features
│   ├── widgets/
│   │   ├── buttons/
│   │   │   ├── primary_button.dart
│   │   │   ├── secondary_button.dart
│   │   │   └── icon_button.dart
│   │   ├── cards/
│   │   │   ├── ad_card.dart
│   │   │   └── category_card.dart
│   │   ├── inputs/
│   │   │   ├── app_text_field.dart
│   │   │   ├── app_dropdown.dart
│   │   │   └── search_bar.dart
│   │   ├── feedback/
│   │   │   ├── app_snackbar.dart
│   │   │   ├── shimmer_loading.dart
│   │   │   ├── empty_state.dart
│   │   │   └── error_view.dart
│   │   ├── layout/
│   │   │   ├── app_scaffold.dart
│   │   │   ├── sliver_app_bar.dart
│   │   │   └── bottom_nav_bar.dart
│   │   └── media/
│   │       ├── cached_avatar.dart
│   │       ├── image_gallery.dart
│   │       └── image_picker_sheet.dart
│   └── models/                         # Shared data models
│       ├── pagination_meta.dart
│       └── api_error.dart
│
├── features/                           # Feature modules
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_api.dart
│   │   ├── domain/
│   │   │   ├── auth_state.dart
│   │   │   └── auth_provider.dart      # Riverpod provider
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── register_screen.dart
│   │       │   └── otp_screen.dart
│   │       └── widgets/
│   │           ├── phone_input.dart
│   │           └── otp_field.dart
│   ├── home/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           ├── category_tab_bar.dart
│   │           ├── banner_carousel.dart
│   │           └── ad_feed.dart
│   ├── ads/
│   │   ├── data/
│   │   │   ├── ad_repository.dart
│   │   │   ├── ad_api.dart
│   │   │   └── models/
│   │   │       ├── ad_model.dart
│   │   │       └── ad_model.g.dart     # json_serializable generated
│   │   ├── domain/
│   │   │   └── ad_providers.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── ad_detail_screen.dart
│   │       │   ├── ad_post_screen.dart
│   │       │   └── my_ads_screen.dart
│   │       └── widgets/
│   │           ├── ad_image_slider.dart
│   │           ├── seller_info_card.dart
│   │           ├── price_tag.dart
│   │           └── pledge_dialog.dart
│   ├── search/
│   ├── chat/
│   ├── favorites/
│   ├── ratings/
│   ├── notifications/
│   ├── commission/
│   └── profile/
```

### 3.3 Mobile Design — Premium & Modern (Haraj Competitor Level)

#### Visual Language

| Aspect | Approach |
|---|---|
| **Overall Feel** | Clean, spacious, content-first — like a blend of Haraj's simplicity with Noon's polish |
| **Cards** | Rounded corners (16px), subtle shadows, white background, generous padding |
| **Images** | Full-width hero on detail, 3:2 aspect ratio thumbnails, shimmer loading |
| **Typography** | IBM Plex Sans Arabic, clear hierarchy (bold titles, regular body, light captions) |
| **Colors** | Deep green primary (#1B5E20), warm gold accent (#F9A825), neutral grays |
| **Bottom Nav** | 5 tabs: Home, Search, Post Ad (+), Chat, Profile — floating style with notch for center FAB |
| **Transitions** | Shared element transitions for ad card → detail, slide-up for modals |
| **Pull to Refresh** | Custom branded refresh indicator |
| **Empty States** | Illustrated (custom SVGs), with clear CTA button |
| **Skeleton Loading** | Shimmer effect matching exact card layout |

#### Key UX Patterns

```
Home Screen Flow:
┌──────────────────────────────────┐
│  ┌────────────────────────────┐  │
│  │  🔍 Search Barq Wadih...  │  │  ← Tappable search bar (opens search screen)
│  └────────────────────────────┘  │
│                                  │
│  ┌─── Banner Carousel ───────┐  │  ← Auto-scroll, page indicator dots
│  │  [Banner 1] [Banner 2]    │  │
│  └────────────────────────────┘  │
│                                  │
│  سيارات | جوالات | أثاث | خدمات  │  ← Scrollable category chips/tabs
│  ───────────────────────────────  │
│                                  │
│  ┌──────┐  ┌──────┐             │  ← 2-column ad grid (like Haraj)
│  │ Ad 1 │  │ Ad 2 │             │     Each card: image, title, price, city, time
│  │      │  │      │             │
│  └──────┘  └──────┘             │
│  ┌──────┐  ┌──────┐             │
│  │ Ad 3 │  │ Ad 4 │             │
│  └──────┘  └──────┘             │
│                                  │
│  ══════════════════════════════  │
│  🏠  🔍  [+]  💬  👤           │  ← Bottom nav (center FAB = post ad)
└──────────────────────────────────┘
```

#### Animation Principles (Flutter)

| Animation | Type | Duration |
|---|---|---|
| Page transitions | `SlideTransition` + `FadeTransition` | 300ms |
| Card tap → detail | `Hero` widget (shared element) | 350ms |
| Bottom sheet | `showModalBottomSheet` + spring curve | 400ms |
| Button press | `ScaleTransition` 0.95 scale | 100ms |
| List item appear | Staggered `FadeTransition` + `SlideTransition` | 200ms each, 50ms stagger |
| Skeleton shimmer | `Shimmer` widget | Continuous loop, 1500ms |
| Pull to refresh | Custom `RefreshIndicator` | Native feel |
| Toast/Snackbar | Slide from bottom + fade | 250ms in, 200ms out |

---

## 4. Design System

### 4.1 Color System

```css
/* ═══════════════════════════════════════
   Barq Wadih — Design Tokens
   Premium Saudi Marketplace Identity
   ═══════════════════════════════════════ */

:root {
  /* ── Primary: Deep Green (Trust, Saudi identity) ── */
  --color-primary-50:  #E8F5E9;
  --color-primary-100: #C8E6C9;
  --color-primary-200: #A5D6A7;
  --color-primary-300: #81C784;
  --color-primary-400: #66BB6A;
  --color-primary-500: #43A047;
  --color-primary-600: #388E3C;
  --color-primary-700: #2E7D32;
  --color-primary-800: #1B5E20;
  --color-primary-900: #0D3B0F;

  /* ── Accent: Warm Gold (Premium, CTA energy) ── */
  --color-accent-50:  #FFF8E1;
  --color-accent-100: #FFECB3;
  --color-accent-200: #FFE082;
  --color-accent-300: #FFD54F;
  --color-accent-400: #FFCA28;
  --color-accent-500: #F9A825;
  --color-accent-600: #F57F17;

  /* ── Neutral: Warm Grays ── */
  --color-neutral-0:   #FFFFFF;
  --color-neutral-50:  #FAFAF9;
  --color-neutral-100: #F5F5F4;
  --color-neutral-200: #E7E5E4;
  --color-neutral-300: #D6D3D1;
  --color-neutral-400: #A8A29E;
  --color-neutral-500: #78716C;
  --color-neutral-600: #57534E;
  --color-neutral-700: #44403C;
  --color-neutral-800: #292524;
  --color-neutral-900: #1C1917;

  /* ── Semantic ── */
  --color-success: #16A34A;
  --color-warning: #EA580C;
  --color-error:   #DC2626;
  --color-info:    #0284C7;

  /* ── Surface (backgrounds) ── */
  --surface-primary:   var(--color-neutral-0);
  --surface-secondary: var(--color-neutral-50);
  --surface-tertiary:  var(--color-neutral-100);
  --surface-elevated:  var(--color-neutral-0);
  --surface-overlay:   rgba(0, 0, 0, 0.5);

  /* ── Text ── */
  --text-primary:   var(--color-neutral-900);
  --text-secondary: var(--color-neutral-600);
  --text-tertiary:  var(--color-neutral-400);
  --text-inverse:   var(--color-neutral-0);
  --text-brand:     var(--color-primary-700);

  /* ── Border ── */
  --border-default: var(--color-neutral-200);
  --border-hover:   var(--color-neutral-300);
  --border-focus:   var(--color-primary-500);
}

/* ── Dark Mode ── */
@media (prefers-color-scheme: dark) {
  :root {
    --surface-primary:   var(--color-neutral-900);
    --surface-secondary: var(--color-neutral-800);
    --surface-tertiary:  var(--color-neutral-700);
    --surface-elevated:  #292524;

    --text-primary:   var(--color-neutral-50);
    --text-secondary: var(--color-neutral-400);
    --text-tertiary:  var(--color-neutral-600);
    --text-inverse:   var(--color-neutral-900);

    --border-default: var(--color-neutral-700);
    --border-hover:   var(--color-neutral-600);
  }
}
```

### 4.2 Typography Scale

```css
:root {
  /* ── Font Families ── */
  --font-arabic: 'IBM Plex Sans Arabic', system-ui, sans-serif;
  --font-english: 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  /* ── Type Scale (modular: 1.25 ratio) ── */
  --text-xs:   0.75rem;    /* 12px — captions, timestamps */
  --text-sm:   0.875rem;   /* 14px — secondary text */
  --text-base: 1rem;       /* 16px — body text */
  --text-lg:   1.125rem;   /* 18px — emphasized body */
  --text-xl:   1.25rem;    /* 20px — card titles */
  --text-2xl:  1.5rem;     /* 24px — section headings */
  --text-3xl:  1.875rem;   /* 30px — page titles */
  --text-4xl:  2.25rem;    /* 36px — hero headings */
  --text-5xl:  3rem;       /* 48px — display headings */

  /* ── Font Weights ── */
  --font-regular:  400;
  --font-medium:   500;
  --font-semibold: 600;
  --font-bold:     700;

  /* ── Line Heights ── */
  --leading-tight:  1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;
}
```

### 4.3 Spacing Scale (4px base grid)

```css
:root {
  --space-0:  0;
  --space-1:  0.25rem;   /* 4px */
  --space-2:  0.5rem;    /* 8px */
  --space-3:  0.75rem;   /* 12px */
  --space-4:  1rem;      /* 16px */
  --space-5:  1.25rem;   /* 20px */
  --space-6:  1.5rem;    /* 24px */
  --space-8:  2rem;      /* 32px */
  --space-10: 2.5rem;    /* 40px */
  --space-12: 3rem;      /* 48px */
  --space-16: 4rem;      /* 64px */
  --space-20: 5rem;      /* 80px */
  --space-24: 6rem;      /* 96px */
}
```

### 4.4 Elevation & Shadows

```css
:root {
  --shadow-xs:  0 1px 2px rgba(0,0,0,0.05);
  --shadow-sm:  0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06);
  --shadow-md:  0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.06);
  --shadow-lg:  0 10px 15px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05);
  --shadow-xl:  0 20px 25px rgba(0,0,0,0.1), 0 10px 10px rgba(0,0,0,0.04);
  --shadow-2xl: 0 25px 50px rgba(0,0,0,0.15);

  --shadow-card:  0 2px 8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04);
  --shadow-card-hover: 0 8px 24px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.06);
  --shadow-modal: 0 24px 48px rgba(0,0,0,0.2);
}
```

### 4.5 Border Radius

```css
:root {
  --radius-sm:   6px;
  --radius-md:   10px;
  --radius-lg:   16px;
  --radius-xl:   24px;
  --radius-2xl:  32px;
  --radius-full: 9999px;    /* pills, avatars */
}
```

### 4.6 Breakpoints

```css
/* Mobile-first approach: base = mobile */
/* --breakpoint-sm:  640px   Mobile landscape */
/* --breakpoint-md:  768px   Tablet */
/* --breakpoint-lg:  1024px  Desktop */
/* --breakpoint-xl:  1280px  Large desktop */
/* --breakpoint-2xl: 1536px  Ultra-wide */
```

### 4.7 Transitions & Animations

```css
:root {
  --transition-fast:   150ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-base:   250ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-slow:   350ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-spring: 500ms cubic-bezier(0.34, 1.56, 0.64, 1);

  --ease-in:     cubic-bezier(0.4, 0, 1, 1);
  --ease-out:    cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
}

/* Keyframes */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to   { opacity: 1; transform: scale(1); }
}
```

### 4.8 RTL Handling Strategy

```css
/* Logical Properties — use INSTEAD of left/right */
/* ✅ CORRECT */
margin-inline-start: var(--space-4);
padding-inline-end: var(--space-2);
border-start-start-radius: var(--radius-md);
inset-inline-start: 0;
text-align: start;

/* ❌ WRONG */
margin-left: 16px;
padding-right: 8px;
border-top-left-radius: 10px;
left: 0;
text-align: left;
```

**Rules:**
1. **NEVER use `left`/`right`** in CSS. Always use `start`/`end` logical properties.
2. Set `dir="rtl"` on `<html>` for Arabic, `dir="ltr"` for English.
3. Icons with directional meaning (arrows, chevrons) must flip in RTL via `transform: scaleX(-1)` or Lucide's RTL variants.
4. Number inputs remain LTR even in RTL layouts (`direction: ltr` on `<input type="number">`).
5. Test every page in BOTH Arabic and English before marking complete.

### 4.9 Icon System

| Platform | Library | Style |
|---|---|---|
| **Web** | Lucide React | Outline style (1.5px stroke), 24×24 default |
| **Mobile** | Iconsax Flutter | Outline (default), Bold (active states), Bulk (illustrations) |

**Rules:**
- Consistent stroke width across all icons
- 24px touch target minimum (actually 44px tap area with padding)
- Semantic names: use `Heart` not `icon-1`
- Always import individual icons (tree-shaking)

---

## 5. Code Quality Guardrails

### 5.1 Linting & Formatting

| Stack | Linter | Formatter | Config |
|---|---|---|---|
| **Backend (PHP)** | Larastan (PHPStan Level 6) | Laravel Pint (PSR-12 + Laravel preset) | `phpstan.neon`, `pint.json` |
| **Frontend (TS)** | ESLint (flat config) + `eslint-config-next` | Prettier | `.eslintrc.cjs`, `.prettierrc` |
| **Mobile (Dart)** | `flutter analyze` (pedantic rules) | `dart format` | `analysis_options.yaml` |

### 5.2 ESLint Rules (Frontend)

```json
{
  "rules": {
    "no-console": "warn",
    "no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unused-vars": "error",
    "react-hooks/exhaustive-deps": "warn",
    "import/order": ["error", {
      "groups": ["builtin", "external", "internal", "parent", "sibling"],
      "newlines-between": "always",
      "alphabetize": { "order": "asc" }
    }],
    "react/jsx-sort-props": "warn"
  }
}
```

### 5.3 Prettier Config

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "bracketSpacing": true,
  "arrowParens": "always"
}
```

### 5.4 Git Hooks (Husky + lint-staged)

```
Pre-commit:
  ├── Frontend: prettier --write + eslint --fix (staged files only)
  ├── Backend:  ./vendor/bin/pint (staged .php files)
  └── Mobile:   dart format (staged .dart files)

Commit-msg:
  └── commitlint (conventional commits enforced)
```

### 5.5 Conventional Commits

```
Format: <type>(<scope>): <subject>

Types:
  feat     — New feature
  fix      — Bug fix
  docs     — Documentation
  style    — Formatting (no logic change)
  refactor — Code refactor (no feature/fix)
  perf     — Performance improvement
  test     — Tests
  chore    — Build, CI, deps
  ci       — CI/CD changes

Scopes: backend, frontend, mobile, infra, docs

Examples:
  feat(backend): add ad creation endpoint with image upload
  fix(frontend): correct RTL alignment on category tab bar
  chore(ci): add Flutter analysis to GitHub Actions
  docs: update sprint-01 with architecture changes
```

### 5.6 PR Checklist (Copy into PR Template)

```markdown
## PR Checklist
- [ ] Code follows the architecture patterns in `docs/ARCHITECTURE.md`
- [ ] No business logic in controllers (backend)
- [ ] No `any` types (frontend)
- [ ] All API data fetched via TanStack Query hooks (frontend)
- [ ] RTL tested — page works in both Arabic and English
- [ ] Dark mode tested (frontend/mobile)
- [ ] Skeleton/loading states implemented
- [ ] Error states handled (empty state, network error, 404)
- [ ] All new strings added to ar.json AND en.json
- [ ] Unit/feature tests added for new logic
- [ ] No N+1 queries (backend — check with Telescope)
- [ ] API response uses correct Resource class
- [ ] Mobile: works on both iOS and Android
- [ ] Screenshots attached (if UI change)
```

---

## 6. Testing Strategy

### 6.1 Testing Pyramid

```
          ┌─────────┐
          │  E2E    │   ~10% — Critical user flows only
          │Playwright│   Auth → Post Ad → Search → Chat → Pay Commission
         ┌┴─────────┴┐
         │ Integration │  ~30% — API endpoint tests, component integration
         │   Tests    │   Backend: HTTP feature tests
         │            │   Frontend: Page-level component tests
        ┌┴────────────┴┐
        │  Unit Tests   │  ~60% — Services, Actions, Utils, Hooks
        │               │  Backend: Service/Action unit tests
        │               │  Frontend: Hook tests, utility tests
        │               │  Mobile: Provider tests, model tests
        └───────────────┘
```

### 6.2 Coverage Targets

| Layer | Target | Tool |
|---|---|---|
| **Backend Services/Actions** | 85%+ | PHPUnit + `php artisan test --coverage` |
| **Backend Controllers** | 90%+ (via feature tests) | PHPUnit HTTP tests |
| **Frontend Components** | 70%+ | Vitest + Testing Library |
| **Frontend Hooks/Utils** | 90%+ | Vitest |
| **Mobile Providers** | 80%+ | `flutter test --coverage` |
| **E2E Critical Flows** | 100% of defined flows | Playwright |

### 6.3 Backend Testing Rules

```php
// ALWAYS: Feature test for every endpoint
// tests/Feature/Api/V1/AdControllerTest.php
public function test_user_can_create_ad_with_valid_data(): void
{
    $user = User::factory()->create();
    $response = $this->actingAs($user)->postJson('/api/v1/ads', [
        'title' => 'نيسان ماكسيما 2020',
        'category_id' => 1,
        'city_id' => 1,
        // ...
    ]);
    $response->assertStatus(201)
             ->assertJsonStructure(['success', 'data' => ['id', 'title']]);
}

// ALWAYS: Unit test for Services/Actions
// tests/Unit/Services/CommissionServiceTest.php
public function test_calculates_percentage_commission(): void
{
    $service = new CommissionService();
    $result = $service->calculate(price: 50000, isDealer: false);
    $this->assertEquals(250.00, $result->amount); // 0.5% of 50000
}
```

### 6.4 Factory & Seeder Strategy

| Factory | Seeds | Purpose |
|---|---|---|
| `UserFactory` | 50 users (5 dealers, 2 admins) | Test data |
| `AdFactory` | 200 ads (mixed statuses) | Feed testing |
| `CategoryFactory` | 15 real categories + subcategories | Production seed |
| `RegionFactory` | 13 Saudi regions | Production seed |
| `CityFactory` | 50+ Saudi cities | Production seed |
| `RatingFactory` | 100 ratings | Review testing |

**Production seeders** (regions, cities, categories, system_settings) are separate from test seeders.

---

## 7. Scalability Patterns

### 7.1 Caching Strategy

```
Layer 1: Browser Cache
  └── Static assets: Cache-Control max-age=31536000 (1 year, hashed filenames)
  └── API responses: Cache-Control no-cache (SWR handles client-side)

Layer 2: CDN (DO Spaces CDN)
  └── Images, media files

Layer 3: Application Cache (Redis)
  ┌────────────────────────┬──────────┬──────────────────────────────┐
  │ Key Pattern            │ TTL      │ Invalidation                 │
  ├────────────────────────┼──────────┼──────────────────────────────┤
  │ categories:tree        │ 24h      │ On category CRUD             │
  │ regions:all            │ 24h      │ On region CRUD               │
  │ cities:region:{id}     │ 24h      │ On city CRUD                 │
  │ system_settings        │ 1h       │ On setting update            │
  │ ad:{id}                │ 15min    │ On ad update/delete          │
  │ user:{id}:profile      │ 30min    │ On profile update            │
  │ home:feed:{city}:{p}   │ 5min     │ Auto-expire                  │
  │ search:{hash}          │ 5min     │ Auto-expire                  │
  └────────────────────────┴──────────┴──────────────────────────────┘

Layer 4: Query Cache (TanStack Query — Frontend)
  └── staleTime: 5min for lists, 15min for static data
  └── gcTime: 30min
  └── refetchOnWindowFocus: true (for critical data)

Layer 5: Search Cache (Meilisearch)
  └── Built-in caching, managed by Meilisearch
```

### 7.2 Database Indexing Strategy

See `DATABASE_SCHEMA.md` for per-table indexes. General rules:

1. **Every foreign key gets an index** (Laravel does this automatically)
2. **Composite indexes for common queries** — column order matches WHERE clause order
3. **Covering indexes** for high-frequency queries (feed, search)
4. **No index on low-cardinality boolean columns alone** — combine with other columns
5. **Monitor slow queries** via Laravel Telescope in dev, slow query log in production
6. **EXPLAIN ANALYZE** before shipping any new complex query

### 7.3 N+1 Prevention

```php
// ❌ NEVER — N+1 query
$ads = Ad::all();
foreach ($ads as $ad) {
    echo $ad->user->name;       // 1 query per ad
    echo $ad->category->name;   // 1 query per ad
}

// ✅ ALWAYS — Eager load
$ads = Ad::with(['user', 'category', 'images', 'city'])->paginate(20);

// Enforce: Install "beyondcode/laravel-query-detector" in dev
// It logs a warning on every N+1 query automatically.
```

### 7.4 Queue Strategy

```
Queue: Redis driver
Queues (by priority):
  1. high     — Payment webhooks, auth events
  2. default  — Notifications, search indexing, counter updates
  3. low      — Analytics logging, image optimization, cleanup jobs

Workers: 2 workers in production
  Worker 1: --queue=high,default (priority processing)
  Worker 2: --queue=default,low

Retry: 3 attempts with exponential backoff
Failed jobs: logged to `failed_jobs` table for admin review
```

### 7.5 Rate Limiting

```php
// bootstrap/app.php or RouteServiceProvider
RateLimiter::for('auth', fn (Request $r) =>
    Limit::perMinute(5)->by($r->ip())
);
RateLimiter::for('api', fn (Request $r) =>
    Limit::perMinute(60)->by($r->user()?->id ?: $r->ip())
);
RateLimiter::for('search', fn (Request $r) =>
    Limit::perMinute(30)->by($r->user()?->id ?: $r->ip())
);
RateLimiter::for('upload', fn (Request $r) =>
    Limit::perHour(20)->by($r->user()->id)
);
RateLimiter::for('ad-create', fn (Request $r) =>
    Limit::perHour(10)->by($r->user()->id)
);
RateLimiter::for('admin', fn (Request $r) =>
    Limit::perMinute(120)->by($r->user()->id)
);
```

---

## 8. Readability Standards

### 8.1 File & Function Size Limits

| Metric | Limit | Action if exceeded |
|---|---|---|
| **File length** | 300 lines max | Split into smaller modules |
| **Function/method** | 30 lines max | Extract sub-functions |
| **Controller method** | 15 lines max | Delegate to Service/Action |
| **Class** | 1 public responsibility | No God classes |
| **Parameters** | 4 max per function | Use DTO/options object |
| **Nesting depth** | 3 levels max | Early return, extract method |
| **Component (React)** | 150 lines max | Extract sub-components |
| **CSS Module** | 200 lines max | Split by component |

### 8.2 Naming Conventions (All Stacks)

| Element | Backend (PHP) | Frontend (TS) | Mobile (Dart) |
|---|---|---|---|
| **Class** | PascalCase | PascalCase | PascalCase |
| **Method/Function** | camelCase | camelCase | camelCase |
| **Variable** | camelCase | camelCase | camelCase |
| **Constant** | UPPER_SNAKE | UPPER_SNAKE | lowerCamelCase |
| **File** | PascalCase.php | PascalCase.tsx / camelCase.ts | snake_case.dart |
| **DB column** | snake_case | — | — |
| **API field** | snake_case (JSON) | camelCase (internal) | camelCase (internal) |
| **Route** | kebab-case | kebab-case | — |
| **CSS class** | camelCase (modules) | camelCase (modules) | — |

### 8.3 Comment Policy

```
Rule: Code should be self-documenting. Comments explain WHY, not WHAT.

✅ GOOD comments:
  // Commission is 90 SAR flat for dealers instead of percentage — business rule from stakeholder
  // We use cursor pagination here because offset pagination degrades at 100k+ rows
  // Firestore has a 1MB document limit, so we paginate messages in subcollection

❌ BAD comments (delete these):
  // Get user by ID
  // Loop through ads
  // Return the response
  // Initialize variables

Required comments:
  • Every Service class: PHPDoc block explaining responsibility
  • Every Action class: PHPDoc block explaining the operation
  • Complex algorithms: Step-by-step explanation
  • Workarounds: Link to issue/ticket explaining why

Forbidden:
  • Commented-out code (delete it, Git has history)
  • TODO without a ticket/issue number
  • Author tags (Git blame handles this)
```

### 8.4 Import Order

```typescript
// Frontend — enforce via ESLint import/order
// 1. Node/built-in
// 2. External packages (react, next, etc.)
// 3. Internal aliases (@/lib, @/components)
// 4. Parent imports (../)
// 5. Sibling imports (./)
// 6. Style imports (.css)

import { useEffect } from 'react';              // external
import { useTranslations } from 'next-intl';     // external

import { apiClient } from '@/lib/api/client';    // internal
import { useAds } from '@/lib/api/queries/useAds'; // internal

import { AdCard } from '../AdCard';              // parent
import styles from './AdGrid.module.css';         // style
```

---

## Appendix: Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                  BARQ WADIH — QUICK RULES                   │
├─────────────────────────────────────────────────────────────┤
│ Controller max: 15 lines  │  Function max: 30 lines        │
│ File max: 300 lines       │  Component max: 150 lines      │
│ Params max: 4             │  Nesting max: 3 levels          │
├─────────────────────────────────────────────────────────────┤
│ No any in TypeScript      │  No left/right in CSS           │
│ No ::all() in Eloquent    │  No lazy loading in queries     │
│ No console.log in prod    │  No commented-out code          │
├─────────────────────────────────────────────────────────────┤
│ PHPStan Level 6           │  ESLint strict + no-any         │
│ 85% backend coverage      │  70% frontend coverage          │
│ Conventional commits      │  PR checklist required          │
├─────────────────────────────────────────────────────────────┤
│ RTL: Use logical props    │  Dark mode: CSS prefers-scheme  │
│ Fonts: IBM Plex Arabic    │  Icons: Lucide (web) Iconsax    │
│ State: TanStack Query     │  Client: Zustand                │
└─────────────────────────────────────────────────────────────┘
```
