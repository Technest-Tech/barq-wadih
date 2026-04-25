'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  fetchBanners, createBanner, deleteBanner, toggleBanner,
  type BannerItem, type PaginatedBanners,
} from '@/lib/api/admin-banners';
import styles from './banners.module.css';

function formatDate(d: string): string {
  return new Date(d).toLocaleDateString('ar-SA', { year: 'numeric', month: 'short', day: 'numeric' });
}

function getBannerStatus(b: BannerItem): { label: string; cls: string } {
  if (!b.is_active) return { label: 'متوقف', cls: styles.badgeInactive };
  if (b.is_live) return { label: 'مباشر', cls: styles.badgeLive };
  if (b.ends_at && new Date(b.ends_at) < new Date()) return { label: 'منتهي', cls: styles.badgeExpired };
  return { label: 'مجدول', cls: styles.badgeScheduled };
}

export default function AdminBannersPage() {
  const [data, setData] = useState<PaginatedBanners | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ position: '', status: '', q: '' });
  const [page, setPage] = useState(1);
  const [showModal, setShowModal] = useState(false);
  const [saving, setSaving] = useState(false);

  // Form
  const [formData, setFormData] = useState({ title: '', link_type: 'none', position: 'home_top', starts_at: '', ends_at: '', link_url: '', link_whatsapp: '', link_ad_id: '', advertiser_name: '', advertiser_phone: '', notes: '', image_url: '' });
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await fetchBanners({ ...filters, page });
      setData(result);
    } catch { /* silent */ } finally { setLoading(false); }
  }, [filters, page]);

  useEffect(() => { loadData(); }, [loadData]);

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) { setImageFile(file); setImagePreview(URL.createObjectURL(file)); }
  };

  const handleCreate = async () => {
    if (!formData.title || !formData.starts_at || !formData.ends_at) return;
    setSaving(true);
    try {
      const fd = new FormData();
      fd.append('title', formData.title);
      fd.append('link_type', formData.link_type);
      fd.append('position', formData.position);
      fd.append('starts_at', formData.starts_at);
      fd.append('ends_at', formData.ends_at);
      if (formData.link_url) fd.append('link_url', formData.link_url);
      if (formData.link_whatsapp) fd.append('link_whatsapp', formData.link_whatsapp);
      if (formData.link_ad_id) fd.append('link_ad_id', formData.link_ad_id);
      if (formData.advertiser_name) fd.append('advertiser_name', formData.advertiser_name);
      if (formData.advertiser_phone) fd.append('advertiser_phone', formData.advertiser_phone);
      if (formData.notes) fd.append('notes', formData.notes);
      if (formData.image_url) fd.append('image_url', formData.image_url);
      if (imageFile) fd.append('image', imageFile);

      await createBanner(fd);
      setShowModal(false);
      setImageFile(null);
      setImagePreview(null);
      setFormData({ title: '', link_type: 'none', position: 'home_top', starts_at: '', ends_at: '', link_url: '', link_whatsapp: '', link_ad_id: '', advertiser_name: '', advertiser_phone: '', notes: '', image_url: '' });
      await loadData();
    } catch { alert('فشل إنشاء البانر'); } finally { setSaving(false); }
  };

  const handleToggle = async (id: number) => {
    try { await toggleBanner(id); await loadData(); } catch { alert('فشل تغيير الحالة'); }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('هل تريد حذف هذا البانر؟')) return;
    try { await deleteBanner(id); await loadData(); } catch { alert('فشل الحذف'); }
  };

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', margin: 0 }}>🖼️ إدارة البانرات</h1>
        <button className={styles.createBtn} onClick={() => setShowModal(true)}>+ بانر جديد</button>
      </div>

      {/* Toolbar */}
      <div className={styles.toolbar}>
        <input className={styles.searchInput} placeholder="🔍 بحث..." value={filters.q} onChange={e => { setFilters(f => ({ ...f, q: e.target.value })); setPage(1); }} />
        <select className={styles.filterSelect} value={filters.position} onChange={e => { setFilters(f => ({ ...f, position: e.target.value })); setPage(1); }}>
          <option value="">كل المواقع</option>
          <option value="home_top">أعلى الرئيسية</option>
          <option value="home_middle">وسط الرئيسية</option>
          <option value="category_top">أعلى القسم</option>
        </select>
        <select className={styles.filterSelect} value={filters.status} onChange={e => { setFilters(f => ({ ...f, status: e.target.value })); setPage(1); }}>
          <option value="">كل الحالات</option>
          <option value="active">نشط</option>
          <option value="inactive">متوقف</option>
          <option value="expired">منتهي</option>
        </select>
      </div>

      {/* Grid */}
      {loading ? (
        <div className={styles.loading}><div className={styles.loadingSpinner} /><span>جاري التحميل...</span></div>
      ) : !data || data.data.length === 0 ? (
        <div className={styles.empty}><span style={{ fontSize: '3rem', display: 'block', marginBottom: '1rem' }}>🖼️</span>لا توجد بانرات</div>
      ) : (
        <>
          <div className={styles.grid}>
            {data.data.map((b: BannerItem) => {
              const st = getBannerStatus(b);
              return (
                <div key={b.id} className={styles.card}>
                  {b.image_url ? (
                    <img src={b.image_url} alt={b.title} className={styles.cardImage} />
                  ) : (
                    <div className={styles.cardImagePlaceholder}>🖼️</div>
                  )}
                  <div className={styles.cardBody}>
                    <div className={styles.cardTitle}>{b.title}</div>
                    <div className={styles.cardMeta}>
                      <span className={`${styles.badge} ${st.cls}`}>{st.label}</span>
                      <span className={styles.positionBadge}>{b.position_label}</span>
                    </div>
                    <div className={styles.dateRange}>
                      {b.starts_at ? formatDate(b.starts_at) : '—'} → {b.ends_at ? formatDate(b.ends_at) : '—'}
                    </div>
                    <div className={styles.statsRow}>
                      <span className={styles.stat}>👁 <span className={styles.statValue}>{b.impressions_count.toLocaleString()}</span></span>
                      <span className={styles.stat}>👆 <span className={styles.statValue}>{b.clicks_count.toLocaleString()}</span></span>
                      <span className={styles.stat}>CTR: <span className={styles.statCtr}>{b.ctr}%</span></span>
                    </div>
                    {b.advertiser_name && <div style={{ fontSize: '.78rem', color: '#94a3b8', marginBottom: '.5rem' }}>👤 {b.advertiser_name}</div>}
                    <div className={styles.cardActions}>
                      <button className={`${styles.toggleBtn} ${b.is_active ? styles.toggleActive : styles.toggleInactive}`} onClick={() => handleToggle(b.id)}>
                        {b.is_active ? '✅ نشط' : '⏸ متوقف'}
                      </button>
                      <button className={styles.deleteBtn} onClick={() => handleDelete(b.id)}>🗑</button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {data.pagination.last_page > 1 && (
            <div className={styles.pagination}>
              <button className={styles.pageBtn} disabled={page <= 1} onClick={() => setPage(p => p - 1)}>←</button>
              <span className={styles.pageInfo}>{page} / {data.pagination.last_page}</span>
              <button className={styles.pageBtn} disabled={page >= data.pagination.last_page} onClick={() => setPage(p => p + 1)}>→</button>
            </div>
          )}
        </>
      )}

      {/* Create Modal */}
      {showModal && (
        <div className={styles.modalOverlay} onClick={() => setShowModal(false)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <h2 className={styles.modalTitle}>🖼️ بانر جديد</h2>

            <div className={styles.formGroup}>
              <label className={styles.formLabel}>العنوان *</label>
              <input className={styles.formInput} value={formData.title} onChange={e => setFormData(f => ({ ...f, title: e.target.value }))} placeholder="عنوان البانر..." />
            </div>

            <div className={styles.formGroup}>
              <label className={styles.formLabel}>صورة البانر</label>
              <div className={styles.imageUpload} onClick={() => document.getElementById('banner-img')?.click()}>
                <input id="banner-img" type="file" accept="image/*" style={{ display: 'none' }} onChange={handleImageChange} />
                {imagePreview ? <img src={imagePreview} alt="Preview" className={styles.imagePreview} /> : <div className={styles.imageUploadLabel}>📁 اضغط لرفع صورة</div>}
              </div>
            </div>

            <div className={styles.formGroup}>
              <label className={styles.formLabel}>أو رابط الصورة</label>
              <input className={styles.formInput} value={formData.image_url} onChange={e => setFormData(f => ({ ...f, image_url: e.target.value }))} placeholder="https://..." dir="ltr" />
            </div>

            <div className={styles.formRow}>
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>الموقع *</label>
                <select className={styles.formSelect} value={formData.position} onChange={e => setFormData(f => ({ ...f, position: e.target.value }))}>
                  <option value="home_top">أعلى الرئيسية</option>
                  <option value="home_middle">وسط الرئيسية</option>
                  <option value="category_top">أعلى القسم</option>
                </select>
              </div>
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>نوع الرابط</label>
                <select className={styles.formSelect} value={formData.link_type} onChange={e => setFormData(f => ({ ...f, link_type: e.target.value }))}>
                  <option value="none">بدون</option>
                  <option value="url">رابط خارجي</option>
                  <option value="ad">إعلان</option>
                  <option value="whatsapp">واتساب</option>
                </select>
              </div>
            </div>

            {formData.link_type === 'url' && (
              <div className={styles.formGroup}><label className={styles.formLabel}>الرابط</label><input className={styles.formInput} value={formData.link_url} onChange={e => setFormData(f => ({ ...f, link_url: e.target.value }))} placeholder="https://..." dir="ltr" /></div>
            )}
            {formData.link_type === 'ad' && (
              <div className={styles.formGroup}><label className={styles.formLabel}>معرّف الإعلان</label><input className={styles.formInput} type="number" value={formData.link_ad_id} onChange={e => setFormData(f => ({ ...f, link_ad_id: e.target.value }))} /></div>
            )}
            {formData.link_type === 'whatsapp' && (
              <div className={styles.formGroup}><label className={styles.formLabel}>رقم الواتساب</label><input className={styles.formInput} value={formData.link_whatsapp} onChange={e => setFormData(f => ({ ...f, link_whatsapp: e.target.value }))} placeholder="+966..." dir="ltr" /></div>
            )}

            <div className={styles.formRow}>
              <div className={styles.formGroup}><label className={styles.formLabel}>تاريخ البداية *</label><input className={styles.formInput} type="date" value={formData.starts_at} onChange={e => setFormData(f => ({ ...f, starts_at: e.target.value }))} /></div>
              <div className={styles.formGroup}><label className={styles.formLabel}>تاريخ النهاية *</label><input className={styles.formInput} type="date" value={formData.ends_at} onChange={e => setFormData(f => ({ ...f, ends_at: e.target.value }))} /></div>
            </div>

            <div className={styles.formRow}>
              <div className={styles.formGroup}><label className={styles.formLabel}>اسم المعلن</label><input className={styles.formInput} value={formData.advertiser_name} onChange={e => setFormData(f => ({ ...f, advertiser_name: e.target.value }))} /></div>
              <div className={styles.formGroup}><label className={styles.formLabel}>هاتف المعلن</label><input className={styles.formInput} value={formData.advertiser_phone} onChange={e => setFormData(f => ({ ...f, advertiser_phone: e.target.value }))} dir="ltr" /></div>
            </div>

            <div className={styles.formGroup}><label className={styles.formLabel}>ملاحظات</label><textarea className={styles.formTextarea} value={formData.notes} onChange={e => setFormData(f => ({ ...f, notes: e.target.value }))} /></div>

            <div className={styles.modalActions}>
              <button className={styles.cancelBtn} onClick={() => setShowModal(false)}>إلغاء</button>
              <button className={styles.submitBtn} disabled={saving || !formData.title || !formData.starts_at || !formData.ends_at} onClick={handleCreate}>
                {saving ? 'جاري الحفظ...' : 'إنشاء البانر'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
