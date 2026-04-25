// ── Shared API types ───────────────────────────────────────────────────────

export type ApiResponse<T> = {
  success: boolean;
  message?: string;
  data: T;
};

export type PaginatedResponse<T> = {
  success: boolean;
  message?: string;
  data: T[];
  meta: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
};

export type ApiError = {
  success: false;
  message: string;
  errors?: Record<string, string[]>;
};

export type HealthStatus = {
  status: 'ok' | 'degraded';
  timestamp: string;
  services: {
    database: 'ok' | 'error';
    redis: 'ok' | 'error';
    meilisearch: 'ok' | 'error';
  };
};
