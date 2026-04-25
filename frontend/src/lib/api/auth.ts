import apiClient from './client';
import type { AuthResponse, AuthUser } from './auth.types';
import type { ApiResponse } from './types';

export const authApi = {
  register: (data: {
    name: string;
    phone: string;
    email?: string;
    password: string;
    password_confirmation: string;
    region_id?: number;
    city_id?: number;
    locale?: string;
  }) => apiClient.post<AuthResponse>('/v1/auth/register', data),

  login: (data: { email: string; password: string }) =>
    apiClient.post<AuthResponse>('/v1/auth/login', data),

  firebase: (data: { firebase_id_token: string; name?: string; locale?: string }) =>
    apiClient.post<AuthResponse>('/v1/auth/firebase', data),

  me: () => apiClient.get<AuthUser>('/v1/auth/me'),

  updateProfile: (data: {
    name?: string;
    bio?: string;
    locale?: string;
    region_id?: number;
    city_id?: number;
  }) => apiClient.put<AuthUser>('/v1/auth/me', data),

  logout: () => apiClient.post<null>('/v1/auth/logout', {}),

  logoutAll: () => apiClient.post<null>('/v1/auth/logout-all', {}),
};
