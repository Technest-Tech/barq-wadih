# Sprint 4 — Categories, Regions & Cities API + UI

> **Sprint**: 4 of 21
> **Phase**: Phase 2 — Core Marketplace
> **Completed**: 2026-04-13
> **Status**: ✅ COMPLETE

---

## Scope

Build the public taxonomy API (categories, regions, cities), wire it to the Next.js UI, index models in Meilisearch via Laravel Scout, and build Flutter selection widgets.

---

## Deliverables

### Backend

| File | Type | Description |
|---|---|---|
| `app/Http/Resources/CategoryResource.php` | NEW | Category API resource — id, name_ar/en, slug, icon, children, fields_count |
| `app/Http/Resources/RegionResource.php` | NEW | Region API resource — id, name_ar/en, slug, cities_count |
| `app/Http/Resources/CityResource.php` | NEW | City API resource — id, name_ar/en, slug, lat/lng, ads_count |
| `app/Http/Controllers/Api/V1/CategoryController.php` | NEW | GET /api/v1/categories — hierarchical tree |
| `app/Http/Controllers/Api/V1/RegionController.php` | NEW | GET /api/v1/regions + GET /api/v1/regions/{slug}/cities |
| `routes/api/v1.php` | MODIFIED | Added 3 Sprint 4 public routes |
| `app/Models/Category.php` | MODIFIED | Added Scout `Searchable` trait + `toSearchableArray`, `searchableAs`, `shouldBeSearchable` |
| `app/Models/City.php` | MODIFIED | Added Scout `Searchable` trait + `toSearchableArray`, `searchableAs`, `shouldBeSearchable` |
| `config/scout.php` | MODIFIED | Added `categories` and `cities` Meilisearch index settings |

### API Contracts

```
GET /api/v1/categories
→ { success: true, data: CategoryTree[] }
   CategoryTree: { id, name_ar, name_en, slug, icon, image, ads_count, fields_count, children: CategoryChild[] }

GET /api/v1/regions
→ { success: true, data: Region[] }
   Region: { id, name_ar, name_en, slug, sort_order, cities_count }

GET /api/v1/regions/{slug}/cities
→ { success: true, data: City[] }
   City: { id, name_ar, name_en, slug, latitude, longitude, ads_count }
   404 if region slug not found
```

### Frontend (Next.js)

| File | Type | Description |
|---|---|---|
| `src/lib/api/endpoints.ts` | MODIFIED | Added CATEGORIES, REGIONS, REGION_CITIES(slug), AUTH_* endpoints |
| `src/lib/api/categories.ts` | NEW | `fetchCategories()` + TypeScript Category types |
| `src/lib/api/regions.ts` | NEW | `fetchRegions()`, `fetchCities(slug)` + Region/City types |
| `src/components/layout/CategoryTabs/CategoryTabs.tsx` | MODIFIED | Wired to real API; skeleton shimmer; graceful fallback to static data |
| `src/components/layout/CategoryTabs/CategoryTabs.module.css` | MODIFIED | Added `.skeleton`, `.skeletonIcon`, `.skeletonLabel` shimmer styles |
| `src/app/[locale]/page.tsx` | MODIFIED | `'use client'` — regions/cities from API; accordion sidebar filter; breadcrumb; mobile city strip |
| `src/app/[locale]/page.module.css` | MODIFIED | Added region accordion, city sub-list, skeleton rows, breadcrumb styles |

### Flutter (Mobile)

| File | Type | Description |
|---|---|---|
| `features/categories/domain/category_model.dart` | NEW | CategoryModel with `fromJson` |
| `features/categories/data/category_api.dart` | NEW | `CategoryRepository` + `categoriesProvider` AsyncNotifier |
| `features/categories/presentation/category_browser_sheet.dart` | NEW | DraggableScrollableSheet: grid → subcategory list |
| `features/regions/domain/region_model.dart` | NEW | RegionModel + CityModel with `fromJson` |
| `features/regions/data/region_api.dart` | NEW | `RegionRepository` + `regionsProvider` + `citiesProvider` family |
| `features/regions/presentation/region_city_picker.dart` | NEW | Two-step cascading picker: region list → city list |

---

## Verification Results

| Check | Result |
|---|---|
| `php artisan route:list` — 3 new routes | ✅ |
| `GET /api/v1/categories` — 13 top-level categories with children | ✅ |
| `GET /api/v1/regions` — 13 Saudi regions with cities_count | ✅ |
| `GET /api/v1/regions/riyadh/cities` — cities returned | ✅ |
| `GET /api/v1/regions/nonexistent/cities` — 404 `{ success: false }` | ✅ |
| Larastan level 6 on all new/modified files | ✅ **0 errors** |
| TypeScript `--noEmit` | ✅ **0 errors** |

---

## Meilisearch Notes

Scout driver defaults to `collection` (works without Docker/Meilisearch running).
When Docker is up, set `SCOUT_DRIVER=meilisearch` in `.env`, then run:

```bash
php artisan scout:import "App\Models\Category"
php artisan scout:import "App\Models\City"
```

Index settings (searchable/filterable attributes) are pre-configured in `config/scout.php`.

---

## Next Sprint

**Sprint 5 — Ad Posting & Management (Backend + Web)**
- Ad CRUD API with image upload to DO Spaces
- Dynamic category fields (EAV)
- Commission auto-calculator
- Next.js ad posting form
