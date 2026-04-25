'use client';
import { useEffect, useState, useCallback } from 'react';
import { fetchAdminRegions, toggleRegion, toggleCity, updateCity, type AdminRegion, type AdminCity } from '@/lib/api/admin';
import s from '../admin-shared.module.css';

export default function AdminRegionsPage() {
  const [regions, setRegions] = useState<AdminRegion[]>([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [expanded, setExpanded] = useState<number | null>(null);
  const [editCity, setEditCity] = useState<AdminCity | null>(null);
  const [cityForm, setCityForm] = useState({ name_ar: '', name_en: '', latitude: '', longitude: '' });
  const [busy, setBusy] = useState(false);

  const showToast = (msg: string, type: 'success' | 'error') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  const load = useCallback(async () => {
    setLoading(true);
    try { const d = await fetchAdminRegions(); setRegions(d); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleToggleRegion = async (region: AdminRegion) => {
    try { await toggleRegion(region.id); showToast(region.is_active ? 'تم تعطيل المنطقة' : 'تم تفعيل المنطقة', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
  };

  const handleToggleCity = async (city: AdminCity) => {
    try { await toggleCity(city.id); showToast(city.is_active ? 'تم تعطيل المدينة' : 'تم تفعيل المدينة', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
  };

  const openEditCity = (city: AdminCity) => {
    setEditCity(city);
    setCityForm({
      name_ar: city.name_ar, name_en: city.name_en,
      latitude: city.latitude?.toString() || '', longitude: city.longitude?.toString() || '',
    });
  };

  const handleSaveCity = async () => {
    if (!editCity) return;
    setBusy(true);
    try {
      await updateCity(editCity.id, {
        name_ar: cityForm.name_ar, name_en: cityForm.name_en,
        latitude: cityForm.latitude ? parseFloat(cityForm.latitude) : null,
        longitude: cityForm.longitude ? parseFloat(cityForm.longitude) : null,
      });
      showToast('تم تحديث المدينة', 'success');
      setEditCity(null); load();
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const totalCities = regions.reduce((acc, r) => acc + r.cities_count, 0);
  const totalAds = regions.reduce((acc, r) => acc + r.ads_count, 0);

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* Edit City Modal */}
      {editCity && (
        <div className={s.modalOverlay} onClick={() => setEditCity(null)}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h3 className={s.modalTitle}>✏️ تعديل مدينة &quot;{editCity.name_ar}&quot;</h3>
            <div className={s.modalField}><label className={s.modalLabel}>الاسم (عربي)</label>
              <input className={s.modalInput} value={cityForm.name_ar} onChange={e => setCityForm({ ...cityForm, name_ar: e.target.value })} /></div>
            <div className={s.modalField}><label className={s.modalLabel}>الاسم (إنجليزي)</label>
              <input className={s.modalInput} value={cityForm.name_en} onChange={e => setCityForm({ ...cityForm, name_en: e.target.value })} /></div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className={s.modalField}><label className={s.modalLabel}>خط العرض</label>
                <input className={s.modalInput} type="number" step="0.000001" value={cityForm.latitude} onChange={e => setCityForm({ ...cityForm, latitude: e.target.value })} placeholder="24.7136" /></div>
              <div className={s.modalField}><label className={s.modalLabel}>خط الطول</label>
                <input className={s.modalInput} type="number" step="0.000001" value={cityForm.longitude} onChange={e => setCityForm({ ...cityForm, longitude: e.target.value })} placeholder="46.6753" /></div>
            </div>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.primary}`} onClick={handleSaveCity} disabled={busy}>حفظ</button>
              <button className={s.btn} onClick={() => setEditCity(null)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <h1 className={s.pageTitle}>🗺️ المناطق والمدن</h1>
          <span className={s.totalBadge}>{regions.length} منطقة · {totalCities} مدينة · {totalAds} إعلان</span>
        </div>
      </div>

      {/* Regions Accordion */}
      {loading ? (
        <div className={s.loading}><div className={s.spinner} /></div>
      ) : regions.length === 0 ? (
        <div className={s.empty}><h3>لا توجد مناطق</h3></div>
      ) : (
        <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
          {regions.map(region => (
            <div key={region.id} className={s.accordion}>
              <div className={s.accordionHeader} onClick={() => setExpanded(expanded === region.id ? null : region.id)}>
                <span className={`${s.accordionArrow} ${expanded === region.id ? s.open : ''}`}>▶</span>
                <div className={s.treeInfo}>
                  <div className={s.treeName}>{region.name_ar}</div>
                  <div className={s.treeSub}>
                    {region.name_en} · {region.cities_count} مدينة · {region.ads_count} إعلان
                  </div>
                </div>
                <div className={s.treeActions} onClick={e => e.stopPropagation()}>
                  <span className={`${s.badge} ${region.is_active ? s.green : s.red}`}>
                    {region.is_active ? 'مفعّل' : 'معطّل'}
                  </span>
                  <button className={`${s.toggle} ${region.is_active ? s.on : ''}`}
                    onClick={() => handleToggleRegion(region)} />
                </div>
              </div>

              {expanded === region.id && (
                <div className={s.accordionBody}>
                  {region.cities.length === 0 ? (
                    <div style={{ padding: 20, textAlign: 'center', color: 'var(--admin-text-muted)' }}>لا توجد مدن</div>
                  ) : (
                    <div style={{ display: 'grid', gap: 1, background: 'var(--admin-border)' }}>
                      {region.cities.map(city => (
                        <div key={city.id} style={{
                          display: 'flex', alignItems: 'center', gap: 12,
                          padding: '10px 16px', background: 'var(--admin-surface)',
                        }}>
                          <div style={{ flex: 1 }}>
                            <div style={{ fontWeight: 600, color: 'var(--admin-text)', fontSize: 14 }}>{city.name_ar}</div>
                            <div style={{ fontSize: 12, color: 'var(--admin-text-muted)' }}>
                              {city.name_en} · {city.ads_count} إعلان
                              {city.latitude && city.longitude && ` · 📍 ${city.latitude.toFixed(2)}, ${city.longitude.toFixed(2)}`}
                            </div>
                          </div>
                          <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                            <button className={`${s.toggle} ${city.is_active ? s.on : ''}`}
                              onClick={() => handleToggleCity(city)} />
                            <button className={`${s.btn} ${s.sm}`} onClick={() => openEditCity(city)}>✏️</button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
