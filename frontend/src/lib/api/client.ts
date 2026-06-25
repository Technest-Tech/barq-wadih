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
    if (response.status === 401 && typeof window !== 'undefined') {
      handleUnauthorized();
    }
    const err = json as ApiError | null;
    throw new ApiClientError(
      err?.message ?? `HTTP ${response.status}`,
      response.status,
      err?.errors
    );
  }

  return json as T;
}

// Token expired / revoked: clear local auth state. The next render of any
// guarded page or layout reads this and redirects to login.
function handleUnauthorized(): void {
  try {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('admin_user');
    // Wipe persisted zustand auth so isAuthenticated flips to false on reload.
    localStorage.removeItem('barq-auth');
  } catch {
    // ignore storage errors (private mode, etc.)
  }
  window.dispatchEvent(new CustomEvent('auth:unauthorized'));
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
   * Upload multipart form data (for ad images / payment receipts). Omits
   * Content-Type so the browser sets the boundary automatically.
   *
   * When `onProgress` is supplied, the request is sent via XMLHttpRequest so the
   * caller can track real upload progress (0–100). Without it, the lighter
   * fetch path is used.
   */
  async postFormData<T>(
    endpoint: string,
    formData: FormData,
    method: 'POST' | 'PATCH' = 'POST',
    onProgress?: (percent: number) => void
  ): Promise<ApiResponse<T>> {
    const url = `${BASE_URL}${endpoint}`;
    const headers: Record<string, string> = {
      Accept: 'application/json',
      // NOTE: Do NOT set Content-Type here — browser sets it with boundary automatically
    };
    let token: string | null = null;
    if (typeof window !== 'undefined') {
      token = localStorage.getItem('auth_token');
      if (token) headers['Authorization'] = `Bearer ${token}`;
    }
    // PATCH via FormData requires _method override for Laravel
    if (method === 'PATCH') formData.append('_method', 'PATCH');

    // Progress-tracked path: XMLHttpRequest exposes upload.onprogress, fetch does not.
    if (onProgress && typeof XMLHttpRequest !== 'undefined') {
      return new Promise<ApiResponse<T>>((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open('POST', url);
        xhr.setRequestHeader('Accept', 'application/json');
        if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
        };
        xhr.onload = () => {
          const json = (() => {
            try {
              return JSON.parse(xhr.responseText);
            } catch {
              return null;
            }
          })();
          if (xhr.status >= 200 && xhr.status < 300) {
            onProgress(100);
            resolve(json as ApiResponse<T>);
          } else {
            if (xhr.status === 401 && typeof window !== 'undefined') handleUnauthorized();
            const err = json as ApiError | null;
            reject(
              new ApiClientError(err?.message ?? `HTTP ${xhr.status}`, xhr.status, err?.errors)
            );
          }
        };
        xhr.onerror = () => reject(new ApiClientError('Network error', 0));
        xhr.send(formData);
      });
    }

    const response = await fetch(url, { method: 'POST', headers, body: formData });
    const json = await response.json().catch(() => null);
    if (!response.ok) {
      if (response.status === 401 && typeof window !== 'undefined') {
        handleUnauthorized();
      }
      const err = json as ApiError | null;
      throw new ApiClientError(
        err?.message ?? `HTTP ${response.status}`,
        response.status,
        err?.errors
      );
    }
    return json as ApiResponse<T>;
  },

  getPaginated<T>(endpoint: string, options?: RequestInit) {
    return request<PaginatedResponse<T>>('GET', endpoint, undefined, options);
  },
};

export { ApiClientError };
export default apiClient;
