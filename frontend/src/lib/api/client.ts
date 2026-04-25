import type { ApiError, ApiResponse, PaginatedResponse } from './types';

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000/api';

class ApiClientError extends Error {
  public readonly status: number;
  public readonly errors?: Record<string, string[]>;

  constructor(message: string, status: number, errors?: Record<string, string[]>) {
    super(message);
    this.name = 'ApiClientError';
    this.status = status;
    this.errors = errors;
  }
}

async function request<T>(
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  endpoint: string,
  body?: unknown,
  options?: RequestInit
): Promise<T> {
  const url = `${BASE_URL}${endpoint}`;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };

  // Attach Sanctum token if available
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('auth_token');
    if (token) headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
    ...options,
  });

  const json = await response.json().catch(() => null);

  if (!response.ok) {
    const err = json as ApiError | null;
    throw new ApiClientError(
      err?.message ?? `HTTP ${response.status}`,
      response.status,
      err?.errors
    );
  }

  return json as T;
}

const apiClient = {
  get<T>(endpoint: string, options?: RequestInit) {
    return request<ApiResponse<T>>('GET', endpoint, undefined, options);
  },

  post<T>(endpoint: string, body: unknown, options?: RequestInit) {
    return request<ApiResponse<T>>('POST', endpoint, body, options);
  },

  put<T>(endpoint: string, body: unknown, options?: RequestInit) {
    return request<ApiResponse<T>>('PUT', endpoint, body, options);
  },

  patch<T>(endpoint: string, body: unknown, options?: RequestInit) {
    return request<ApiResponse<T>>('PATCH', endpoint, body, options);
  },

  delete<T>(endpoint: string, options?: RequestInit) {
    return request<ApiResponse<T>>('DELETE', endpoint, undefined, options);
  },

  /**
   * Upload multipart form data (for ad images). Omits Content-Type so browser sets boundary.
   */
  async postFormData<T>(
    endpoint: string,
    formData: FormData,
    method: 'POST' | 'PATCH' = 'POST'
  ): Promise<ApiResponse<T>> {
    const url = `${BASE_URL}${endpoint}`;
    const headers: Record<string, string> = {
      Accept: 'application/json',
      // NOTE: Do NOT set Content-Type here — browser sets it with boundary automatically
    };
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('auth_token');
      if (token) headers['Authorization'] = `Bearer ${token}`;
    }
    // PATCH via FormData requires _method override for Laravel
    if (method === 'PATCH') formData.append('_method', 'PATCH');
    const response = await fetch(url, { method: 'POST', headers, body: formData });
    const json = await response.json().catch(() => null);
    if (!response.ok) {
      const err = json as ApiError | null;
      throw new ApiClientError(err?.message ?? `HTTP ${response.status}`, response.status, err?.errors);
    }
    return json as ApiResponse<T>;
  },

  getPaginated<T>(endpoint: string, options?: RequestInit) {
    return request<PaginatedResponse<T>>('GET', endpoint, undefined, options);
  },
};

export { ApiClientError };
export default apiClient;
