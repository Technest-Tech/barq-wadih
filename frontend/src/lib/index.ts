// API lib barrel export
export { default as apiClient, ApiClientError } from './api/client';
export { default as ENDPOINTS } from './api/endpoints';
export type { ApiResponse, PaginatedResponse, ApiError, HealthStatus } from './api/types';

// Hooks
export { useApi, useApiPaginated, useApiMutation } from './hooks/useApi';
