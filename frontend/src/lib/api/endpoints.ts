// ── Central endpoint registry ──────────────────────────────────────────────

const ENDPOINTS = {
  // Health
  HEALTH: '/v1/health',

  // ── Sprint 3: Auth ─────────────────────────────────────────────────────
  AUTH_LOGIN: '/v1/auth/login',
  AUTH_REGISTER: '/v1/auth/register',
  AUTH_LOGOUT: '/v1/auth/logout',
  AUTH_ME: '/v1/auth/me',
  AUTH_AVATAR: '/v1/auth/me/avatar',
  AUTH_COVER: '/v1/auth/me/cover',

  // ── Sprint 4: Categories & Regions ─────────────────────────────────────
  CATEGORIES: '/v1/categories',
  REGIONS: '/v1/regions',
  /** All cities flat list — GET /v1/cities */
  ALL_CITIES: '/v1/cities',
  /** Call as: REGION_CITIES('riyadh') → '/v1/regions/riyadh/cities' */
  REGION_CITIES: (slug: string) => `/v1/regions/${slug}/cities`,
  /** Districts within a city — GET /v1/cities/{id}/districts */
  CITY_DISTRICTS: (cityId: number) => `/v1/cities/${cityId}/districts`,

  // ── Sprint 5: Ads ────────────────────────────────────────────────────────
  ADS: '/v1/ads',
  /** Call as: AD_DETAIL(42) → '/v1/ads/42' */
  AD_DETAIL: (id: number) => `/v1/ads/${id}`,
  MY_ADS: '/v1/ads/mine',
  /** Call as: AD_MARK_SOLD(42) → '/v1/ads/42/sold' */
  AD_MARK_SOLD: (id: number) => `/v1/ads/${id}/sold`,
  /** Call as: AD_UPDATE(42) → '/v1/ads/42' */
  AD_UPDATE: (id: number) => `/v1/ads/${id}`,
  /** Call as: AD_DELETE(42) → '/v1/ads/42' */
  AD_DELETE: (id: number) => `/v1/ads/${id}`,
  /** Call as: CATEGORY_FIELDS(3) → '/v1/categories/3/fields' */
  CATEGORY_FIELDS: (categoryId: number) => `/v1/categories/${categoryId}/fields`,
  /** Commission preview — GET /v1/ads/commission-preview?price=X&is_free=0 */
  COMMISSION_PREVIEW: '/v1/ads/commission-preview',

  // ── Publish-fee payment lifecycle ─────────────────────────────────────
  /** Create payment intent — POST /v1/ads/{id}/payment/init */
  AD_PAYMENT_INIT: (id: number) => `/v1/ads/${id}/payment/init`,
  /** Confirm payment — POST /v1/ads/{id}/payment/confirm */
  AD_PAYMENT_CONFIRM: (id: number) => `/v1/ads/${id}/payment/confirm`,
  /** Upload bank-transfer receipt — POST /v1/ads/{id}/payment/proof */
  AD_PAYMENT_PROOF: (id: number) => `/v1/ads/${id}/payment/proof`,

  // ── Sprint 7: Search ─────────────────────────────────────────────────────
  /** Full-text search — GET /v1/search?q=&category_id=&city_id=&price_min=&... */
  SEARCH: '/v1/search',
  /** Autocomplete suggestions — GET /v1/search/suggestions?q= */
  SEARCH_SUGGESTIONS: '/v1/search/suggestions',
  /** Most-viewed ads fallback — GET /v1/search/popular?limit=3&category_id= */
  SEARCH_POPULAR: '/v1/search/popular',

  // ── Sprint 8: Chat ───────────────────────────────────────────────────────
  /** Mint Firebase custom token — GET /v1/chat/token */
  CHAT_TOKEN: '/v1/chat/token',
  /** List conversations — GET /v1/chat/conversations */
  CHAT_CONVERSATIONS: '/v1/chat/conversations',
  /** Create conversation — POST /v1/chat/conversations */
  CHAT_CREATE: '/v1/chat/conversations',
  /** Notify receiver — POST /v1/chat/conversations/{id}/notify */
  CHAT_NOTIFY: (id: string) => `/v1/chat/conversations/${id}/notify`,

  // ── Sprint 9: Ratings ────────────────────────────────────────────────────
  /** Ratings for an ad's seller — GET /v1/ads/{id}/ratings */
  AD_RATINGS: (id: number) => `/v1/ads/${id}/ratings`,
  /** Submit rating — POST /v1/ads/{id}/ratings */
  AD_RATE: (id: number) => `/v1/ads/${id}/ratings`,
  /** Public seller profile — GET /v1/users/{id} */
  USER_PROFILE: (id: number) => `/v1/users/${id}`,
  /** Seller's active ads — GET /v1/users/{id}/ads */
  USER_ADS: (id: number) => `/v1/users/${id}/ads`,
  /** Ratings received by a user — GET /v1/users/{id}/ratings */
  USER_RATINGS: (id: number) => `/v1/users/${id}/ratings`,
  /** Rating summary (avg + distribution) — GET /v1/users/{id}/rating-summary */
  USER_RATING_SUMMARY: (id: number) => `/v1/users/${id}/rating-summary`,
  /** Delete own rating — DELETE /v1/ratings/{id} */
  DELETE_RATING: (id: number) => `/v1/ratings/${id}`,

  // ── Questions ────────────────────────────────────────────────────────────
  /** List questions for an ad — GET /v1/ads/{id}/questions */
  AD_QUESTIONS: (id: number) => `/v1/ads/${id}/questions`,
  /** Post a question — POST /v1/ads/{id}/questions */
  AD_QUESTION_POST: (id: number) => `/v1/ads/${id}/questions`,
  /** Reply to a question — POST /v1/questions/{id}/reply */
  QUESTION_REPLY: (id: number) => `/v1/questions/${id}/reply`,

  // ── Sprint 9: Favorites ──────────────────────────────────────────────────
  /** User's favorited ads — GET /v1/favorites */
  FAVORITES: '/v1/favorites',
  /** Toggle favorite — POST /v1/ads/{id}/favorite */
  AD_FAVORITE: (id: number) => `/v1/ads/${id}/favorite`,
  /** Favorite status — GET /v1/ads/{id}/favorite-status */
  AD_FAVORITE_STATUS: (id: number) => `/v1/ads/${id}/favorite-status`,

  // ── Sprint 9: Reports ────────────────────────────────────────────────────
  /** Report an ad — POST /v1/ads/{id}/report */
  AD_REPORT: (id: number) => `/v1/ads/${id}/report`,
  /** Report reason list — GET /v1/reports/reasons */
  REPORT_REASONS: '/v1/reports/reasons',

  // ── Sprint 10: Devices ──────────────────────────────────────────────────
  /** Register device token — POST /v1/devices */
  DEVICE_REGISTER: '/v1/devices',

  // ── Sprint 10: Category Follow ────────────────────────────────────────
  /** Toggle follow — POST /v1/categories/{id}/follow */
  CATEGORY_FOLLOW: (id: number) => `/v1/categories/${id}/follow`,
  /** Follow status — GET /v1/categories/{id}/follow-status */
  CATEGORY_FOLLOW_STATUS: (id: number) => `/v1/categories/${id}/follow-status`,
  /** User's followed categories — GET /v1/follows */
  FOLLOWS: '/v1/follows',

  // ── Seller (User) Follow ──────────────────────────────────────────────
  /** Toggle seller follow — POST /v1/users/{id}/follow */
  USER_FOLLOW: (id: number) => `/v1/users/${id}/follow`,
  /** Seller follow status — GET /v1/users/{id}/follow-status */
  USER_FOLLOW_STATUS: (id: number) => `/v1/users/${id}/follow-status`,
  /** Followed sellers list — GET /v1/seller-follows */
  SELLER_FOLLOWS: '/v1/seller-follows',

  // ── Sprint 10: Notifications ──────────────────────────────────────────
  /** Paginated notifications — GET /v1/notifications */
  NOTIFICATIONS: '/v1/notifications',
  /** Mark single read — POST /v1/notifications/{id}/read */
  NOTIFICATION_READ: (id: number) => `/v1/notifications/${id}/read`,
  /** Mark all as read — POST /v1/notifications/read-all */
  NOTIFICATIONS_READ_ALL: '/v1/notifications/read-all',
  /** Unread count — GET /v1/notifications/unread-count */
  NOTIFICATIONS_UNREAD: '/v1/notifications/unread-count',

  // ── Sprint 12: Banners ────────────────────────────────────────────────────
  /** Active banners by position — GET /v1/banners?position=home_top */
  BANNERS: '/v1/banners',
  /** Track click — POST /v1/banners/{id}/click */
  BANNER_CLICK: (id: number) => `/v1/banners/${id}/click`,

  // ── Sprint 13: Boost & Refresh ────────────────────────────────────────────
  /** Boost config — GET /v1/boost-config */
  BOOST_CONFIG: '/v1/boost-config',
  /** Premium boost — POST /v1/ads/{id}/boost */
  AD_BOOST: (id: number) => `/v1/ads/${id}/boost`,
  /** Refresh ad — POST /v1/ads/{id}/refresh */
  AD_REFRESH: (id: number) => `/v1/ads/${id}/refresh`,
  /** Boost history — GET /v1/ads/{id}/boost-history */
  AD_BOOST_HISTORY: (id: number) => `/v1/ads/${id}/boost-history`,

  // ── Sprint 14: Admin Panel ────────────────────────────────────────────────
  /** Admin dashboard KPIs — GET /v1/admin/dashboard/stats */
  ADMIN_DASHBOARD_STATS: '/v1/admin/dashboard/stats',
  /** Admin user list — GET /v1/admin/users */
  ADMIN_USERS: '/v1/admin/users',
  /** Admin user detail — GET /v1/admin/users/{id} */
  ADMIN_USER_DETAIL: (id: number) => `/v1/admin/users/${id}`,
  /** Toggle user status — PATCH /v1/admin/users/{id}/status */
  ADMIN_USER_STATUS: (id: number) => `/v1/admin/users/${id}/status`,
  /** Change user role — PATCH /v1/admin/users/{id}/role */
  ADMIN_USER_ROLE: (id: number) => `/v1/admin/users/${id}/role`,

  // ── Sprint 15: Admin Ad Moderation ─────────────────────────────────────
  ADMIN_ADS: '/v1/admin/ads',
  ADMIN_AD_DETAIL: (id: number) => `/v1/admin/ads/${id}`,
  ADMIN_AD_APPROVE: (id: number) => `/v1/admin/ads/${id}/approve`,
  ADMIN_AD_REJECT: (id: number) => `/v1/admin/ads/${id}/reject`,
  ADMIN_AD_RESTORE: (id: number) => `/v1/admin/ads/${id}/restore`,

  // ── Sprint 15: Admin Reports ───────────────────────────────────────────
  ADMIN_REPORTS: '/v1/admin/reports',
  ADMIN_REPORT_DETAIL: (id: number) => `/v1/admin/reports/${id}`,
  ADMIN_REPORT_RESOLVE: (id: number) => `/v1/admin/reports/${id}/resolve`,
  ADMIN_REPORT_DISMISS: (id: number) => `/v1/admin/reports/${id}/dismiss`,

  // ── Sprint 15: Admin Categories ────────────────────────────────────────
  ADMIN_CATEGORIES: '/v1/admin/categories',
  ADMIN_CATEGORY_DETAIL: (id: number) => `/v1/admin/categories/${id}`,
  ADMIN_CATEGORY_TOGGLE: (id: number) => `/v1/admin/categories/${id}/toggle`,
  ADMIN_CATEGORIES_REORDER: '/v1/admin/categories/reorder',
  ADMIN_CATEGORY_FIELDS: (id: number) => `/v1/admin/categories/${id}/fields`,
  ADMIN_FIELD_DETAIL: (id: number) => `/v1/admin/fields/${id}`,

  // ── Sprint 15: Admin Regions & Cities ──────────────────────────────────
  ADMIN_REGIONS: '/v1/admin/regions',
  ADMIN_REGION_TOGGLE: (id: number) => `/v1/admin/regions/${id}/toggle`,
  ADMIN_CITY_TOGGLE: (id: number) => `/v1/admin/cities/${id}/toggle`,
  ADMIN_CITY_UPDATE: (id: number) => `/v1/admin/cities/${id}`,

  // ── Public Static Pages ────────────────────────────────────────────────
  /** Fetch a published page by slug — GET /v1/pages/{slug} */
  STATIC_PAGE: (slug: string) => `/v1/pages/${slug}`,

  // ── Sprint 15: Admin Static Pages ──────────────────────────────────────
  ADMIN_PAGES: '/v1/admin/pages',
  ADMIN_PAGE_DETAIL: (id: number) => `/v1/admin/pages/${id}`,

  // ── Sprint 16: Admin Commissions ──────────────────────────────────────
  ADMIN_COMMISSIONS: '/v1/admin/commissions',
  ADMIN_COMMISSION_DETAIL: (id: number) => `/v1/admin/commissions/${id}`,
  ADMIN_COMMISSION_STATUS: (id: number) => `/v1/admin/commissions/${id}/status`,
  ADMIN_COMMISSIONS_SUMMARY: '/v1/admin/commissions/summary',
  ADMIN_COMMISSIONS_EXPORT: '/v1/admin/commissions/export',

  // ── Bank-transfer payment-proof review ────────────────────────────────
  ADMIN_PAYMENT_PROOFS: '/v1/admin/payment-proofs',
  ADMIN_PAYMENT_PROOFS_PENDING_COUNT: '/v1/admin/payment-proofs/pending-count',
  ADMIN_PAYMENT_PROOF_APPROVE: (id: number) => `/v1/admin/payment-proofs/${id}/approve`,
  ADMIN_PAYMENT_PROOF_REJECT: (id: number) => `/v1/admin/payment-proofs/${id}/reject`,

  // ── Sprint 16: Admin Analytics ────────────────────────────────────────
  ADMIN_ANALYTICS_REVENUE: '/v1/admin/analytics/revenue',
  ADMIN_ANALYTICS_ADS_BY_CITY: '/v1/admin/analytics/ads-by-city',
  ADMIN_ANALYTICS_SEARCH_TERMS: '/v1/admin/analytics/search-terms',
  ADMIN_ANALYTICS_ZERO_RESULTS: '/v1/admin/analytics/zero-results',

  // ── Sprint 17: Admin Notification Campaigns ───────────────────────────
  ADMIN_NOTIFICATION_STATS: '/v1/admin/notifications/stats',
  ADMIN_NOTIFICATION_CAMPAIGNS: '/v1/admin/notifications/campaigns',
  ADMIN_NOTIFICATION_CAMPAIGN_DETAIL: (id: number) => `/v1/admin/notifications/campaigns/${id}`,
  ADMIN_NOTIFICATION_CAMPAIGN_SEND: (id: number) => `/v1/admin/notifications/campaigns/${id}/send`,
  ADMIN_NOTIFICATION_CAMPAIGN_SCHEDULE: (id: number) =>
    `/v1/admin/notifications/campaigns/${id}/schedule`,

  // ── Sprint 17: Admin Banners ──────────────────────────────────────────
  ADMIN_BANNERS: '/v1/admin/banners',
  ADMIN_BANNER_DETAIL: (id: number) => `/v1/admin/banners/${id}`,
  ADMIN_BANNER_TOGGLE: (id: number) => `/v1/admin/banners/${id}/toggle`,
  ADMIN_BANNER_ANALYTICS: (id: number) => `/v1/admin/banners/${id}/analytics`,

  // ── Sprint 17: Admin Settings ─────────────────────────────────────────
  ADMIN_SETTINGS: '/v1/admin/settings',
  ADMIN_SETTINGS_BULK: '/v1/admin/settings/bulk',
  ADMIN_SETTING_DETAIL: (key: string) => `/v1/admin/settings/${key}`,

  // ── Contact Us ────────────────────────────────────────────────────────
  CONTACT_CATEGORIES: '/v1/contact/categories',
  CONTACT_SUBMIT: '/v1/contact',
  ADMIN_CONTACT: '/v1/admin/contact',
  ADMIN_CONTACT_DETAIL: (id: number) => `/v1/admin/contact/${id}`,
  ADMIN_CONTACT_STATUS: (id: number) => `/v1/admin/contact/${id}/status`,
} as const;

export default ENDPOINTS;
