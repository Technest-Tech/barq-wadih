'use client';

import React, { use, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { authApi } from '@/lib/api/auth';
import { useAuthStore } from '@/store/auth.store';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import { fetchRegions, fetchCities, type Region, type City } from '@/lib/api/regions';
import type { AuthUser } from '@/lib/api/auth.types';
import styles from './page.module.css';

// ── Helpers ──────────────────────────────────────────────────────────────────

function formatJoinDate(iso: string): string {
  return new Date(iso).toLocaleDateString('ar-SA', { year: 'numeric', month: 'long' });
}

function avgNum(v: string | number | undefined): number {
  if (v === undefined || v === null) return 0;
  return typeof v === 'string' ? parseFloat(v) || 0 : v;
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function ProfilePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  const { ready } = useRequireAuth(`/${locale}/login`);
  const router = useRouter();
  const { user: storeUser, updateUser, clearAuth } = useAuthStore();

  const [user, setUser] = useState<AuthUser | null>(storeUser);
  const [loading, setLoading] = useState(true);

  // ── Image uploads ─────────────────────────────────────────────────────────
  const avatarRef = useRef<HTMLInputElement | null>(null);
  const coverRef  = useRef<HTMLInputElement | null>(null);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingCover,  setUploadingCover]  = useState(false);

  // ── Name editing ──────────────────────────────────────────────────────────
  const [editingName, setEditingName] = useState(false);
  const [nameText,    setNameText]    = useState('');
  const [savingName,  setSavingName]  = useState(false);

  // ── Bio editing ───────────────────────────────────────────────────────────
  const [editingBio, setEditingBio] = useState(false);
  const [bioText,    setBioText]    = useState('');
  const [savingBio,  setSavingBio]  = useState(false);

  // ── Region / City ─────────────────────────────────────────────────────────
  const [regions,        setRegions]        = useState<Region[]>([]);
  const [cities,         setCities]         = useState<City[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<number | ''>('');
  const [selectedCity,   setSelectedCity]   = useState<number | ''>('');
  const [savingLocation, setSavingLocation] = useState(false);
  const [locationEdited, setLocationEdited] = useState(false);

  // ── Fetch fresh user data ─────────────────────────────────────────────────
  useEffect(() => {
    if (!ready) return;
    authApi.me()
      .then((res) => {
        const u = res.data!;
        setUser(u);
        updateUser(u);
        setSelectedRegion(u.region?.id ?? '');
        setSelectedCity(u.city?.id ?? '');
      })
      .catch(() => {
        if (storeUser) {
          setSelectedRegion(storeUser.region?.id ?? '');
          setSelectedCity(storeUser.city?.id ?? '');
        }
      })
      .finally(() => setLoading(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  // ── Load regions ──────────────────────────────────────────────────────────
  useEffect(() => {
    fetchRegions().then(setRegions).catch(() => {});
  }, []);

  // ── Load cities when region changes ──────────────────────────────────────
  useEffect(() => {
    if (!selectedRegion) { setCities([]); return; }
    const region = regions.find((r) => r.id === selectedRegion);
    if (!region) return;
    fetchCities(region.slug).then(setCities).catch(() => {});
  }, [selectedRegion, regions]);

  // ── Handlers ─────────────────────────────────────────────────────────────

  async function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setUploadingAvatar(true);
    try {
      const res = await authApi.uploadAvatar(file);
      const newUrl = res.data?.avatar_url ?? null;
      setUser((u) => u ? { ...u, avatar_url: newUrl } : u);
      if (user) updateUser({ ...user, avatar_url: newUrl });
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل رفع الصورة');
    } finally {
      setUploadingAvatar(false);
    }
  }

  async function handleCoverChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setUploadingCover(true);
    try {
      const res = await authApi.uploadCover(file);
      const newUrl = res.data?.cover_image_url ?? null;
      setUser((u) => u ? { ...u, cover_image_url: newUrl } : u);
      if (user) updateUser({ ...user, cover_image_url: newUrl });
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل رفع الغلاف');
    } finally {
      setUploadingCover(false);
    }
  }

  function openNameEdit() {
    setNameText(user?.name ?? '');
    setEditingName(true);
  }

  async function saveName() {
    if (!nameText.trim()) return;
    setSavingName(true);
    try {
      const res = await authApi.updateProfile({ name: nameText.trim() });
      const updated = res.data!;
      setUser((u) => u ? { ...u, name: updated.name } : u);
      updateUser({ ...user!, name: updated.name });
      setEditingName(false);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل الحفظ');
    } finally {
      setSavingName(false);
    }
  }

  function openBioEdit() {
    setBioText(user?.bio ?? '');
    setEditingBio(true);
  }

  async function saveBio() {
    setSavingBio(true);
    try {
      const res = await authApi.updateProfile({ bio: bioText.trim() });
      const newBio = res.data?.bio ?? bioText.trim();
      setUser((u) => u ? { ...u, bio: newBio } : u);
      updateUser({ ...user!, bio: newBio });
      setEditingBio(false);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل حفظ النبذة');
    } finally {
      setSavingBio(false);
    }
  }

  async function saveLocation() {
    setSavingLocation(true);
    try {
      const res = await authApi.updateProfile({
        region_id: selectedRegion || undefined,
        city_id:   selectedCity   || undefined,
      });
      const updated = res.data!;
      setUser((u) => u ? { ...u, region: updated.region, city: updated.city } : u);
      updateUser({ ...user!, region: updated.region, city: updated.city });
      setLocationEdited(false);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل حفظ الموقع');
    } finally {
      setSavingLocation(false);
    }
  }

  async function handleLogout() {
    if (!confirm('هل تريد تسجيل الخروج؟')) return;
    try { await authApi.logout(); } catch { /* ignore */ }
    clearAuth();
    router.push(`/${locale}`);
  }

  // ── Render ────────────────────────────────────────────────────────────────

  if (!ready) return null;

  if (loading) {
    return (
      <>
        <Header />
        <div className={styles.coverSkeleton} />
        <main className={styles.page}>
          <div className={styles.container}>
            <div className={styles.skeletonCard} />
            <div className={styles.skeletonCard} />
          </div>
        </main>
        <Footer />
      </>
    );
  }

  if (!user) return null;

  const avg = avgNum(user.avg_rating);

  return (
    <>
      <Header />

      {/* ── Cover ── */}
      <section
        className={`${styles.cover} ${user.cover_image_url ? styles.coverWithImage : ''}`}
        style={user.cover_image_url ? { backgroundImage: `url(${user.cover_image_url})` } : undefined}
      >
        {user.cover_image_url && <div className={styles.coverOverlay} />}
        <button
          type="button"
          className={styles.coverEditBtn}
          onClick={() => coverRef.current?.click()}
          disabled={uploadingCover}
        >
          {uploadingCover
            ? <><span className={`${styles.spinner} ${styles.spinnerDark}`} /> جارٍ الرفع</>
            : '📷 تغيير الغلاف'}
        </button>
        <input ref={coverRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={handleCoverChange} />
      </section>

      <main className={styles.page}>
        <div className={styles.container}>

          {/* ── Identity card ── */}
          <section className={styles.identityCard}>

            {/* Avatar */}
            <div className={styles.avatarWrap}>
              {user.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={user.avatar_url} alt={user.name} />
              ) : (
                <span>{user.name?.charAt(0) ?? '؟'}</span>
              )}
              {user.is_verified && <span className={styles.verifiedDot} title="موثوق">✓</span>}
              <button
                type="button"
                className={styles.avatarEditBtn}
                onClick={() => avatarRef.current?.click()}
                disabled={uploadingAvatar}
                aria-label="تغيير الصورة"
              >
                {uploadingAvatar ? <span className={styles.spinner} /> : '📷'}
              </button>
              <input ref={avatarRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={handleAvatarChange} />
            </div>

            {/* Name + badges + bio */}
            <div className={styles.identityBody}>

              {/* Name row */}
              {editingName ? (
                <div className={styles.inlineEditRow}>
                  <input
                    className={styles.inlineInput}
                    value={nameText}
                    onChange={(e) => setNameText(e.target.value)}
                    maxLength={100}
                    autoFocus
                    onKeyDown={(e) => { if (e.key === 'Enter') saveName(); if (e.key === 'Escape') setEditingName(false); }}
                  />
                  <button className={styles.inlineSave}  onClick={saveName}               disabled={savingName}>{savingName ? '...' : 'حفظ'}</button>
                  <button className={styles.inlineCancel} onClick={() => setEditingName(false)} disabled={savingName}>إلغاء</button>
                </div>
              ) : (
                <div className={styles.nameRow}>
                  <h1 className={styles.name}>{user.name}</h1>
                  {user.is_verified && <span className={styles.verifiedBadge}>✓ موثوق</span>}
                  {user.is_dealer  && <span className={styles.dealerBadge}>⭐ معرض</span>}
                  <button className={styles.fieldEditBtn} onClick={openNameEdit} aria-label="تعديل الاسم">✏️</button>
                </div>
              )}

              {/* Join date */}
              <p className={styles.joinDate}>عضو منذ {formatJoinDate(user.created_at)}</p>

              {/* Bio */}
              {editingBio ? (
                <div className={styles.bioEditWrap}>
                  <textarea
                    className={styles.bioTextarea}
                    value={bioText}
                    onChange={(e) => setBioText(e.target.value)}
                    maxLength={500}
                    rows={3}
                    placeholder="اكتب نبذة تعريفية عنك..."
                    autoFocus
                  />
                  <div className={styles.bioEditActions}>
                    <button className={styles.bioSaveBtn}   onClick={saveBio}               disabled={savingBio}>{savingBio ? '...حفظ' : 'حفظ'}</button>
                    <button className={styles.bioCancelBtn} onClick={() => setEditingBio(false)} disabled={savingBio}>إلغاء</button>
                  </div>
                </div>
              ) : (
                <div className={styles.bioRow}>
                  {user.bio
                    ? <p className={styles.bio}>{user.bio}</p>
                    : <p className={styles.bioPlaceholder}>أضف نبذة تعريفية عنك...</p>
                  }
                  <button className={styles.fieldEditBtn} onClick={openBioEdit} aria-label="تعديل النبذة">✏️</button>
                </div>
              )}

              {/* Public profile link */}
              <Link href={`/${locale}/users/${user.id}`} className={styles.publicProfileLink}>
                عرض الملف العام ←
              </Link>
            </div>
          </section>

          {/* ── Stats strip ── */}
          <section className={styles.statsStrip}>
            <div className={styles.statItem}>
              <span className={styles.statVal}>{user.total_ads_count}</span>
              <span className={styles.statLbl}>إجمالي الإعلانات</span>
            </div>
            <div className={styles.statDivider} />
            <div className={styles.statItem}>
              <span className={styles.statVal}>{avg > 0 ? avg.toFixed(1) : '—'}</span>
              <span className={styles.statLbl}>متوسط التقييم</span>
            </div>
            <div className={styles.statDivider} />
            <div className={styles.statItem}>
              <span className={styles.statVal}>{user.rating_count}</span>
              <span className={styles.statLbl}>عدد التقييمات</span>
            </div>
            <div className={styles.statDivider} />
            <div className={styles.statItem}>
              <span className={styles.statVal}>{user.unread_notifications_count}</span>
              <span className={styles.statLbl}>إشعار غير مقروء</span>
            </div>
          </section>

          {/* ── Contact info ── */}
          <section className={styles.card}>
            <h2 className={styles.cardTitle}>معلومات الاتصال</h2>
            <div className={styles.infoGrid}>
              <div className={styles.infoItem}>
                <span className={styles.infoIcon}>📧</span>
                <div>
                  <span className={styles.infoLabel}>البريد الإلكتروني</span>
                  <span className={styles.infoValue}>{user.email ?? '—'}</span>
                  {user.email && !user.email_verified_at && (
                    <span className={styles.unverifiedBadge}>غير موثق</span>
                  )}
                </div>
              </div>
              <div className={styles.infoItem}>
                <span className={styles.infoIcon}>📱</span>
                <div>
                  <span className={styles.infoLabel}>رقم الجوال</span>
                  <span className={styles.infoValue} dir="ltr">{user.phone ?? '—'}</span>
                  {user.phone && !user.phone_verified_at && (
                    <span className={styles.unverifiedBadge}>غير موثق</span>
                  )}
                </div>
              </div>
            </div>
          </section>

          {/* ── Location ── */}
          <section className={styles.card}>
            <h2 className={styles.cardTitle}>الموقع الجغرافي</h2>
            <div className={styles.locationGrid}>
              <div className={styles.selectWrap}>
                <label className={styles.selectLabel}>المنطقة</label>
                <select
                  className={styles.select}
                  value={selectedRegion}
                  onChange={(e) => {
                    setSelectedRegion(e.target.value ? Number(e.target.value) : '');
                    setSelectedCity('');
                    setLocationEdited(true);
                  }}
                >
                  <option value="">— اختر المنطقة —</option>
                  {regions.map((r) => (
                    <option key={r.id} value={r.id}>{r.name_ar}</option>
                  ))}
                </select>
              </div>
              <div className={styles.selectWrap}>
                <label className={styles.selectLabel}>المدينة</label>
                <select
                  className={styles.select}
                  value={selectedCity}
                  disabled={!selectedRegion || cities.length === 0}
                  onChange={(e) => {
                    setSelectedCity(e.target.value ? Number(e.target.value) : '');
                    setLocationEdited(true);
                  }}
                >
                  <option value="">— اختر المدينة —</option>
                  {cities.map((c) => (
                    <option key={c.id} value={c.id}>{c.name_ar}</option>
                  ))}
                </select>
              </div>
            </div>
            {locationEdited && (
              <button
                className={styles.saveLocationBtn}
                onClick={saveLocation}
                disabled={savingLocation}
              >
                {savingLocation ? '...جارٍ الحفظ' : 'حفظ الموقع'}
              </button>
            )}
            {!locationEdited && (user.region || user.city) && (
              <p className={styles.currentLocation}>
                📍 {[user.region?.name_ar, user.city?.name_ar].filter(Boolean).join('، ')}
              </p>
            )}
          </section>

          {/* ── Quick links ── */}
          <section className={styles.card}>
            <h2 className={styles.cardTitle}>الوصول السريع</h2>
            <div className={styles.quickLinks}>
              <Link href={`/${locale}/favorites`} className={styles.quickLink}>
                <span className={styles.quickIcon}>❤️</span>
                <span>المفضلة</span>
                <span className={styles.quickChevron}>←</span>
              </Link>
              <Link href={`/${locale}/follows`} className={styles.quickLink}>
                <span className={styles.quickIcon}>👥</span>
                <span>المتابَعون</span>
                <span className={styles.quickChevron}>←</span>
              </Link>
              <Link href={`/${locale}/notifications`} className={styles.quickLink}>
                <span className={styles.quickIcon}>🔔</span>
                <div className={styles.quickLinkBody}>
                  <span>الإشعارات</span>
                  {user.unread_notifications_count > 0 && (
                    <span className={styles.notifBadge}>{user.unread_notifications_count}</span>
                  )}
                </div>
                <span className={styles.quickChevron}>←</span>
              </Link>
              <Link href={`/${locale}/messages`} className={styles.quickLink}>
                <span className={styles.quickIcon}>✉️</span>
                <span>الرسائل</span>
                <span className={styles.quickChevron}>←</span>
              </Link>
              <Link href={`/${locale}/post-ad`} className={styles.quickLink}>
                <span className={styles.quickIcon}>➕</span>
                <span>نشر إعلان جديد</span>
                <span className={styles.quickChevron}>←</span>
              </Link>
            </div>
          </section>

          {/* ── Danger zone ── */}
          <section className={styles.dangerCard}>
            <button className={styles.logoutBtn} onClick={handleLogout}>
              🚪 تسجيل الخروج
            </button>
          </section>

        </div>
      </main>

      <Footer />
    </>
  );
}
