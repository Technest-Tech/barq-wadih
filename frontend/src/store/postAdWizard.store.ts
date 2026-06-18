// ── Post-Ad Wizard — Zustand store ────────────────────────────────────────
//
// Holds the entire wizard state across the 9 steps and persists a serializable
// draft to localStorage so a refresh never loses work. Files (image blobs)
// are NOT persisted — they're rebuilt from previews when needed.

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { Category, CategoryChild } from '@/lib/api/categories';
import type { Region, City } from '@/lib/api/regions';
import type { District } from '@/lib/api/districts';

export type WizardStep =
  | 'category'
  | 'pledge'
  | 'region'
  | 'city'
  | 'district'
  | 'map'
  | 'images'
  | 'details'
  | 'review';

export const STEP_ORDER: WizardStep[] = [
  'category',
  'pledge',
  'region',
  'city',
  'district',
  'map',
  'images',
  'details',
  'review',
];

export type WizardImage = {
  /** Stable id used as the React key. New uploads start with `new-`. */
  id: string;
  /** data:URL for previews (safe to persist; cheap on small thumbnails). */
  previewUrl: string;
  /** When set, this is an existing AdImage from the backend (edit mode). */
  existingId?: number;
  /** Mark for removal on submit (edit mode only). */
  removed?: boolean;
};

export type WizardDetails = {
  title: string;
  description: string;
  price: string; // Keep as string for the input; cast on submit.
  isFree: boolean; // مجاني — no price at all.
  isNegotiable: boolean; // قابل للتفاوض.
  priceHidden: boolean; // اتصل للسعر — distinct from is_free.
  phone: string;
  showPhonePublicly: boolean;
  /** Dynamic category fields keyed by field_key. */
  fields: Record<string, string>;
};

export type WizardState = {
  step: WizardStep;
  // Step 1 — Category + seller type
  parentCategory: Category | null;
  category: CategoryChild | Category | null;
  sellerType: 'individual' | 'dealer' | null;
  // Step 2 — Pledge
  pledgeAccepted: boolean;
  // Steps 3–6 — Location
  region: Region | null;
  city: City | null;
  district: District | null;
  districtFreeText: string;
  latLng: { lat: number; lng: number } | null;
  // Step 7 — Images (in display order; primary = images[0] not removed)
  images: WizardImage[];
  // Step 8 — Details
  details: WizardDetails;
  // Edit mode
  editingAdId: number | null;

  // ── actions ─────────────────────────────────────────────────────────────
  setStep: (s: WizardStep) => void;
  goNext: () => void;
  goBack: () => void;
  setParentCategory: (c: Category | null) => void;
  setCategory: (c: CategoryChild | Category | null) => void;
  setSellerType: (t: 'individual' | 'dealer') => void;
  setPledgeAccepted: (v: boolean) => void;
  setRegion: (r: Region | null) => void;
  setCity: (c: City | null) => void;
  setDistrict: (d: District | null) => void;
  setDistrictFreeText: (t: string) => void;
  setLatLng: (p: { lat: number; lng: number } | null) => void;
  setImages: (i: WizardImage[]) => void;
  addImages: (imgs: WizardImage[]) => void;
  removeImage: (id: string) => void;
  reorderImages: (fromIdx: number, toIdx: number) => void;
  patchDetails: (p: Partial<WizardDetails>) => void;
  setEditingAdId: (id: number | null) => void;
  reset: () => void;
};

const INITIAL_DETAILS: WizardDetails = {
  title: '',
  description: '',
  price: '',
  isFree: false,
  isNegotiable: false,
  priceHidden: false,
  phone: '',
  showPhonePublicly: true,
  fields: {},
};

const INITIAL_STATE = {
  step: 'category' as WizardStep,
  parentCategory: null,
  category: null,
  sellerType: 'individual' as 'individual' | 'dealer' | null,
  pledgeAccepted: false,
  region: null,
  city: null,
  district: null,
  districtFreeText: '',
  latLng: null,
  images: [] as WizardImage[],
  details: INITIAL_DETAILS,
  editingAdId: null,
};

export const usePostAdWizard = create<WizardState>()(
  persist(
    (set, get) => ({
      ...INITIAL_STATE,

      setStep: (step) => set({ step }),
      goNext: () => {
        const i = STEP_ORDER.indexOf(get().step);
        if (i < STEP_ORDER.length - 1) set({ step: STEP_ORDER[i + 1] });
      },
      goBack: () => {
        const i = STEP_ORDER.indexOf(get().step);
        if (i > 0) set({ step: STEP_ORDER[i - 1] });
      },

      setParentCategory: (parentCategory) => set({ parentCategory, category: null }),
      setCategory: (category) => set({ category }),
      setSellerType: (sellerType) => set({ sellerType }),
      setPledgeAccepted: (pledgeAccepted) => set({ pledgeAccepted }),

      setRegion: (region) =>
        set({ region, city: null, district: null, districtFreeText: '', latLng: null }),
      setCity: (city) => set({ city, district: null, districtFreeText: '', latLng: null }),
      setDistrict: (district) => set({ district, districtFreeText: '' }),
      setDistrictFreeText: (districtFreeText) => set({ districtFreeText, district: null }),
      setLatLng: (latLng) => set({ latLng }),

      setImages: (images) => set({ images }),
      addImages: (imgs) => set({ images: [...get().images, ...imgs] }),
      removeImage: (id) =>
        set({
          images: get()
            .images.map((img) =>
              img.id === id ? (img.existingId ? { ...img, removed: true } : null) : img
            )
            .filter((x): x is WizardImage => x !== null),
        }),
      reorderImages: (from, to) => {
        const next = [...get().images];
        const [moved] = next.splice(from, 1);
        next.splice(to, 0, moved);
        set({ images: next });
      },

      patchDetails: (p) => set({ details: { ...get().details, ...p } }),
      setEditingAdId: (editingAdId) => set({ editingAdId }),

      reset: () => set({ ...INITIAL_STATE }),
    }),
    {
      name: 'barq:post-ad:draft:v1',
      storage: createJSONStorage(() => {
        if (typeof window !== 'undefined') return window.localStorage;
        return {
          getItem: () => null,
          setItem: () => {},
          removeItem: () => {},
          clear: () => {},
          key: () => null,
          length: 0,
        } satisfies Storage;
      }),
      // Defer rehydration until the client mounts. The wizard root calls
      // `usePostAdWizard.persist.rehydrate()` inside a useEffect so the SSR
      // payload always matches the first client paint.
      skipHydration: true,
      partialize: (s) => ({
        parentCategory: s.parentCategory,
        category: s.category,
        sellerType: s.sellerType,
        pledgeAccepted: s.pledgeAccepted,
        region: s.region,
        city: s.city,
        district: s.district,
        districtFreeText: s.districtFreeText,
        latLng: s.latLng,
        images: s.images.filter((img) => img.existingId), // only persist existing images
        details: s.details,
      }),
    }
  )
);

// ── Phone normalization ───────────────────────────────────────────────────
//
// The backend insists on `05XXXXXXXX` or `+9665XXXXXXXX`, but users type
// numbers in many forms — Arabic-Indic digits (٠١٢٣...), spaces, dashes,
// `+966 5...`, `00966 5...`, etc. Normalize once here so the wizard's gate
// and the FormData submit both speak the same canonical form.

const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const PERSIAN = '۰۱۲۳۴۵۶۷۸۹';

export function normalizePhone(raw: string): string {
  if (!raw) return '';
  // Translate Arabic-Indic / Persian digits to ASCII
  let s = '';
  for (const ch of raw) {
    const a = ARABIC_INDIC.indexOf(ch);
    if (a >= 0) {
      s += String(a);
      continue;
    }
    const p = PERSIAN.indexOf(ch);
    if (p >= 0) {
      s += String(p);
      continue;
    }
    s += ch;
  }
  // Strip everything that isn't a digit or a leading +
  s = s.replace(/(?!^\+)\D/g, '').trim();
  // 00966… → +966…
  if (s.startsWith('00')) s = '+' + s.slice(2);
  // 9665… → +9665…
  if (/^9665\d{8}$/.test(s)) s = '+' + s;
  // +9665XXXXXXXX → 05XXXXXXXX (canonical local form)
  if (/^\+9665\d{8}$/.test(s)) s = '0' + s.slice(4);
  // 5XXXXXXXX (missing leading 0) → 05XXXXXXXX
  if (/^5\d{8}$/.test(s)) s = '0' + s;
  return s;
}

export function isValidSaudiPhone(raw: string): boolean {
  const n = normalizePhone(raw);
  return /^05\d{8}$/.test(n);
}

// ── Step-completion selectors ─────────────────────────────────────────────
//
// Each step reports whether the user can advance from it. The wizard footer
// reads `canAdvance(currentStep)` to enable/disable the Next button.

export function canAdvance(state: WizardState, step: WizardStep): boolean {
  switch (step) {
    case 'category':
      return !!state.category;
    case 'pledge':
      return state.pledgeAccepted;
    case 'region':
      return !!state.region;
    case 'city':
      return !!state.city;
    case 'district':
      return !!state.district || state.districtFreeText.trim().length > 0;
    case 'map':
      return !!state.latLng;
    case 'images':
      return state.images.filter((i) => !i.removed).length >= 1;
    case 'details': {
      const d = state.details;
      const phoneOk = !d.showPhonePublicly || isValidSaudiPhone(d.phone);
      return (
        d.title.trim().length >= 3 &&
        d.description.trim().length >= 10 &&
        phoneOk &&
        (d.isFree || d.priceHidden || d.price.trim().length > 0)
      );
    }
    case 'review':
      return true;
  }
}

export function isStepComplete(state: WizardState, step: WizardStep): boolean {
  // For the stepper UI: a step is "complete" if the user has successfully
  // advanced past it — same predicate as canAdvance for now, but separate so
  // it can diverge (e.g. require explicit visit to district before allowing jump-back).
  return canAdvance(state, step);
}
