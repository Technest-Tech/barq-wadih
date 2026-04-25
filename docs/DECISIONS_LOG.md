# Barq Wadih — Decisions Log

> Every significant technical or design decision is logged here with rationale. This prevents re-debating settled choices and provides context for future developers.

---

## Decision Format

| Field | Description |
|---|---|
| **ID** | Sequential (DEC-001, DEC-002, ...) |
| **Date** | When the decision was made |
| **Category** | backend / frontend / mobile / design / infra / process |
| **Decision** | What was decided |
| **Alternatives Considered** | What else was evaluated |
| **Rationale** | Why this choice was made |
| **Status** | `accepted` / `superseded` / `revisit` |

---

## Decisions

### DEC-001 · Backend Architecture: Service + Action Layer (not Repository Pattern)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | backend |
| Decision | Use Service classes for business logic + Action classes for single-purpose operations. Repositories are optional (only for complex queries). |
| Alternatives | (a) Repository Pattern for everything — too much boilerplate for Laravel's Eloquent. (b) Fat Controllers — unmaintainable. (c) Domain-Driven Design — over-engineered for this project size. |
| Rationale | Services handle reusable business logic (AdService, CommissionService). Actions handle one-off operations (DeclareAdSaleAction). This avoids Repository boilerplate while keeping controllers thin. Eloquent scopes handle 90% of query reuse. |
| Status | `accepted` |

---

### DEC-002 · Frontend State: TanStack Query (server) + Zustand (client)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | frontend |
| Decision | TanStack Query v5 for all server state (API data). Zustand for client-only state (UI, auth token, filters). |
| Alternatives | (a) Redux Toolkit + RTK Query — too much boilerplate, overkill for this project. (b) SWR — less feature-rich than TanStack Query (no mutations, no devtools). (c) React Context for everything — causes re-render cascades, not scalable. |
| Rationale | TanStack Query handles caching, dedup, background refetch, pagination, and optimistic updates out of the box. Zustand is 1KB, zero boilerplate, and works perfectly for the small amount of client state we need. |
| Status | `accepted` |

---

### DEC-003 · Styling: Vanilla CSS + CSS Modules (no Tailwind, no CSS-in-JS)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | frontend |
| Decision | Use vanilla CSS with CSS custom properties (design tokens) + CSS Modules for component scoping. |
| Alternatives | (a) Tailwind CSS — fast prototyping but produces messy JSX, hard to maintain design system, poor RTL story. (b) Styled Components — runtime CSS-in-JS has performance cost, poor SSR. (c) CSS Modules + Sass — Sass adds unnecessary complexity. |
| Rationale | CSS custom properties give us a design token system. CSS Modules give scoping. No runtime cost. Full control over RTL via logical properties. This is how Linear and Vercel build their UIs. |
| Status | `accepted` |

---

### DEC-004 · Mobile State Management: Riverpod 2.x
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | mobile |
| Decision | Use Riverpod 2.x for all state management in Flutter. |
| Alternatives | (a) BLoC — more boilerplate (events, states, blocs), harder to test. (b) Provider — simpler but lacks compile-time safety and autoDispose. (c) GetX — magic strings, poor testability, not recommended for production apps. |
| Rationale | Riverpod is compile-safe, supports auto-dispose, has no BuildContext dependency (testable), handles async natively with AsyncValue, and is the recommended modern approach by the Flutter community. |
| Status | `accepted` |

---

### DEC-005 · Mobile Navigation: GoRouter
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | mobile |
| Decision | Use GoRouter for navigation with declarative route definitions. |
| Alternatives | (a) Navigator 2.0 raw — extremely verbose and complex. (b) auto_route — good but GoRouter has better Riverpod integration and is Google-maintained. |
| Rationale | GoRouter is maintained by the Flutter team, supports deep linking out of the box (critical for app store requirements), type-safe routes, redirect guards, and integrates cleanly with Riverpod. |
| Status | `accepted` |

---

### DEC-006 · Icon System: Lucide (Web) + Iconsax (Mobile)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design |
| Decision | Lucide React for web, Iconsax for Flutter. |
| Alternatives | (a) Heroicons — limited set (~300), only outline and solid. (b) React Icons bundle — bundles ALL icons, bad for bundle size. (c) Custom icon font — maintenance overhead. (d) Phosphor Icons — good but Iconsax has better Arabic/premium aesthetic. |
| Rationale | Lucide is tree-shakeable (import only used icons), has 1000+ icons, consistent 1.5px stroke, MIT licensed. Iconsax has outline, bold, and bulk variants which lets us use outline for inactive and bold for active states in bottom nav — premium feel. |
| Status | `accepted` |

---

### DEC-007 · Animation: Framer Motion (Web) + flutter_animate (Mobile)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design |
| Decision | Framer Motion for Next.js, flutter_animate for Flutter. |
| Alternatives | (a) CSS-only animations — limited (no layout, no exit, no gesture). (b) react-spring — less popular, worse docs. (c) GSAP — overkill, commercial license concerns. |
| Rationale | Framer Motion has layout animations, AnimatePresence for exit, gesture support, and works with Next.js App Router. flutter_animate provides chainable, staggered animations with a declarative API — perfect for list items and page transitions. |
| Status | `accepted` |

---

### DEC-008 · Color Palette: Deep Green Primary + Warm Gold Accent
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design |
| Decision | Primary: Deep Green (#1B5E20-#43A047). Accent: Warm Gold (#F9A825). Neutrals: Warm Grays (stone palette). |
| Alternatives | (a) Blue — too generic, used by every tech product. (b) Teal — similar to Haraj, would look like a clone. (c) Red/Orange — too aggressive for a trust-based marketplace. |
| Rationale | Green represents trust, growth, and Saudi national identity (flag color). Gold conveys premium quality and is a natural complement. Warm grays (stone palette) feel organic and natural, matching the Arabic marketplace aesthetic. This combination differentiates from Haraj's blue/teal while feeling premium. |
| Status | `accepted` |

---

### DEC-009 · Typography: IBM Plex Sans Arabic + Inter
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design |
| Decision | IBM Plex Sans Arabic for Arabic text, Inter for English text and numerals. |
| Alternatives | (a) Noto Sans Arabic — good but slightly less refined. (b) Cairo — popular but overused in Arabic web. (c) Tajawal — good but limited weights. |
| Rationale | IBM Plex Sans Arabic is purpose-built for Arabic digital interfaces, has excellent readability at all sizes, multiple weights (400-700), and pairs perfectly with Inter. This combination is used by premium Arabic products. |
| Status | `accepted` |

---

### DEC-010 · Forms: React Hook Form + Zod (Web), flutter_form_builder (Mobile)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | frontend, mobile |
| Decision | React Hook Form + Zod for web forms. flutter_form_builder for mobile forms. |
| Alternatives | (a) Formik — re-renders on every keystroke (controlled). (b) Native form validation — no schema reuse. |
| Rationale | React Hook Form uses uncontrolled inputs (performant), Zod schemas are reusable between client and server validation, and TypeScript inference is excellent. flutter_form_builder provides declarative form fields with built-in validation. |
| Status | `accepted` |

---

### DEC-011 · PHPStan Level 6 (not max)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | backend |
| Decision | Run Larastan at level 6 (not level 8/9/max). |
| Alternatives | Level 8/9/max — catches more issues but produces many false positives with Laravel's magic (facades, dynamic relations, accessors). |
| Rationale | Level 6 catches real bugs (undefined variables, wrong types, missing return types) without fighting Laravel's dynamic patterns. Level 8+ requires extensive baseline/ignore configurations that slow down development. Can be increased later as the team grows. |
| Status | `accepted` |

---

### DEC-012 · Feature-First Architecture for Flutter (not Layer-First)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | mobile |
| Decision | Organize Flutter code by feature (`features/auth/`, `features/ads/`, etc.) with internal clean architecture layers (data/domain/presentation) per feature. |
| Alternatives | (a) Layer-first (`models/`, `screens/`, `services/`) — doesn't scale, hard to find related code. (b) Pure clean architecture — too many layers and abstractions for a Flutter app. |
| Rationale | Feature-first keeps related code together (ad screen, ad model, ad repository, ad provider all in `features/ads/`). Each feature has its own data/domain/presentation split for testability. Shared code lives in `core/` and `shared/`. This is the architecture recommended by Andrea Bizzotto and used by production Flutter apps at scale. |
| Status | `accepted` |

---

### DEC-013 · HTTP: Native Fetch Wrapper (Web), Dio + Retrofit (Mobile)
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | frontend, mobile |
| Decision | Use native `fetch` with a typed wrapper for Next.js. Use Dio + Retrofit for Flutter. |
| Alternatives | (a) Axios for web — adds a dependency for something fetch does natively. Next.js extends fetch with caching. (b) http package for Flutter — no interceptors, no type-safe codegen. |
| Rationale | Next.js extends native fetch with request dedup and caching. Adding Axios would bypass these features. Dio provides interceptors (auth, locale, error mapping) and Retrofit provides type-safe API generation via code generation. |
| Status | `accepted` |

---

### DEC-014 · Dark Mode: CSS `prefers-color-scheme` + Manual Toggle
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design |
| Decision | Support dark mode via CSS `prefers-color-scheme` media query with semantic token overrides. Add manual toggle (stored in localStorage/Zustand). |
| Alternatives | (a) Dark mode only — alienates users who prefer light. (b) No dark mode — unacceptable in 2026 for a premium app. |
| Rationale | CSS custom properties make this near-zero effort if designed from the start. All colors use semantic tokens (--surface-primary, --text-primary) which get overridden in dark mode. Manual toggle gives users control. |
| Status | `accepted` |

---

### DEC-015 · Mobile Design Aesthetic: "Clean Saudi Premium"
| Field | Value |
|---|---|
| Date | 2026-04-08 |
| Category | design, mobile |
| Decision | Visual style: spacious card-based layouts, subtle shadows, 16px rounded corners, shimmer loading, hero shared-element transitions, floating bottom nav with center FAB for "Post Ad", staggered list animations. Competitive target: better than Haraj, comparable to Noon/Mrsool polish level. |
| Alternatives | (a) Minimal flat design — too plain, doesn't convey premium. (b) Skeuomorphic — outdated. (c) Material Design 3 default — looks too generic/Google-y. |
| Rationale | Saudi users expect premium app quality (they use Noon, Mrsool, STC Pay daily). Haraj's UI is functional but dated. We differentiate by being noticeably more polished: better typography, smoother animations, more generous whitespace, and consistent design language across every screen. |
| Status | `accepted` |
