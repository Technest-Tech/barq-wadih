// ── Admin Settings API — Sprint 17 ────────────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

export interface SettingItem {
  key: string;
  value: string;
  type: string;
  type_label: string;
  group: string;
  description: string | null;
  updated_at: string | null;
}

export interface SettingGroup {
  group: string;
  settings: SettingItem[];
}

export async function fetchSettings(): Promise<SettingGroup[]> {
  const res = await apiClient.get<SettingGroup[]>(ENDPOINTS.ADMIN_SETTINGS);
  return res.data;
}

export async function fetchSetting(key: string): Promise<SettingItem> {
  const res = await apiClient.get<SettingItem>(ENDPOINTS.ADMIN_SETTING_DETAIL(key));
  return res.data;
}

export async function updateSetting(key: string, value: string | number | boolean) {
  return apiClient.put(ENDPOINTS.ADMIN_SETTING_DETAIL(key), { value });
}

export async function bulkUpdateSettings(settings: { key: string; value: string | number | boolean }[]) {
  return apiClient.put(ENDPOINTS.ADMIN_SETTINGS_BULK, { settings });
}
