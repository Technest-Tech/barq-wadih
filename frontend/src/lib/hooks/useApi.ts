'use client';

import { useQuery, useMutation, type UseQueryOptions } from '@tanstack/react-query';
import apiClient, { ApiClientError } from '@/lib/api/client';
import type { ApiResponse, PaginatedResponse } from '@/lib/api/types';

/**
 * useApi — TanStack Query wrapper for GET requests
 */
export function useApi<T>(
  queryKey: unknown[],
  endpoint: string,
  options?: Omit<UseQueryOptions<ApiResponse<T>, ApiClientError>, 'queryKey' | 'queryFn'>
) {
  return useQuery<ApiResponse<T>, ApiClientError>({
    queryKey,
    queryFn: () => apiClient.get<T>(endpoint),
    ...options,
  });
}

/**
 * useApiPaginated — TanStack Query wrapper for paginated GET requests
 */
export function useApiPaginated<T>(
  queryKey: unknown[],
  endpoint: string,
  options?: Omit<UseQueryOptions<PaginatedResponse<T>, ApiClientError>, 'queryKey' | 'queryFn'>
) {
  return useQuery<PaginatedResponse<T>, ApiClientError>({
    queryKey,
    queryFn: () => apiClient.getPaginated<T>(endpoint),
    ...options,
  });
}

/**
 * useApiMutation — TanStack Mutation wrapper for POST/PUT/PATCH/DELETE
 */
export function useApiMutation<TData, TBody = unknown>(
  method: 'post' | 'put' | 'patch' | 'delete',
  endpoint: string
) {
  return useMutation<ApiResponse<TData>, ApiClientError, TBody>({
    mutationFn: (body) => {
      if (method === 'delete') {
        return apiClient.delete<TData>(endpoint);
      }
      return apiClient[method as 'post' | 'put' | 'patch']<TData>(endpoint, body as unknown);
    },
  });
}
