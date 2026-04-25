'use client';

import { useState, useEffect, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { createConversation } from '@/lib/api/chat';
import { useAuthStore } from '@/store/auth.store';
import StarRating from '@/components/ratings/StarRating';
import RatingModal from '@/components/ratings/RatingModal';
import ReportModal from '@/components/reports/ReportModal';
import type { Ad, AdListItem } from '@/lib/api/ads';
import { fetchAds } from '@/lib/api/ads';
import AuthModal from '@/components/auth/AuthModal';
import styles from './page.module.css';

// ── Helpers ───────────────────────────────────────────────────────────────────

function relativeTime(dateStr: string | null): string {
  if (!dateStr) return '—';
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} دقيقة`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `منذ ${diffHr} ساعة`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 30) return `منذ ${diffDay} يوم`;
  return new Date(dateStr).toLocaleDateString('ar-SA');
}

interface AdDetailClientProps {
  ad: Ad;
}

export default function AdDetailClient({ ad }: AdDetailClientProps) {
  const { locale } = useParams<{ locale: string }>();
  const router = useRouter();
  const { user, isAuthenticated } = useAuthStore();
  const [activeImg, setActiveImg] = useState(0);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [shareToast, setShareToast] = useState(false);
  const [chatLoading, setChatLoading] = useState(false);
  const [showRatingModal, setShowRatingModal] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [pendingAuthAction, setPendingAuthAction] = useState<'chat' | 'rate' | 'report' | 'follow' | 'reply' | 'comment' | 'follow_ads' | 'favorite' | 'share' | null>(null);
  const [similarAds, setSimilarAds] = useState<AdListItem[]>([]);

  useEffect(() => {
    if (ad.category) {
      fetchAds({ category_id: ad.category.id, page: 1 }).then(res => {
        setSimilarAds(res.data.filter(a => a.id !== ad.id).slice(0, 10));
      }).catch(() => {});
    }
  }, [ad.category, ad.id]);

  const executeAction = async (action: 'chat' | 'rate' | 'report' | 'follow' | 'reply' | 'comment' | 'follow_ads' | 'favorite' | 'share') => {
    if (action === 'chat') {
      setChatLoading(true);
      try {
        const result = await createConversation(ad.id);
        router.push(`/${locale}/messages/${result.conversation_id}`);
      } catch { /* ignore */ } finally { setChatLoading(false); }
    } else if (action === 'rate') {
      setShowRatingModal(true);
    } else if (action === 'report') {
      setShowReportModal(true);
    } else if (action === 'share') {
      handleShare();
    }
    // other actions like follow, reply, comment, favorite don't have APIs hooked up yet
  };

  const requireAuth = (action: 'chat' | 'rate' | 'report' | 'follow' | 'reply' | 'comment' | 'follow_ads' | 'favorite' | 'share') => {
    if (!isAuthenticated) {
      setPendingAuthAction(action);
      setShowAuthModal(true);
    } else {
      executeAction(action);
    }
  };

  const handleAuthSuccess = () => {
    setShowAuthModal(false);
    if (pendingAuthAction) {
      executeAction(pendingAuthAction);
      setPendingAuthAction(null);
    }
  };

  // ── Keyboard lightbox close ───────────────────────────────────────────────

  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (!lightboxOpen) return;
    if (e.key === 'Escape') setLightboxOpen(false);
    if (e.key === 'ArrowRight') setActiveImg(i => (i + 1) % ad.images.length);
    if (e.key === 'ArrowLeft') setActiveImg(i => (i - 1 + ad.images.length) % ad.images.length);
  }, [lightboxOpen, ad]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  // ── Share handler ─────────────────────────────────────────────────────────

  const handleShare = async () => {
    const url = window.location.href;
    if (navigator.share) {
      try { await navigator.share({ title: ad?.title, url }); } catch { /* dismissed */ }
    } else {
      await navigator.clipboard.writeText(url);
      setShareToast(true);
      setTimeout(() => setShareToast(false), 2500);
    }
  };

  const priceDisplay = ad.is_free ? 'مجاني' : `${Number(ad.price ?? 0).toLocaleString('ar-SA')} ر.س`;

  return (
    <>
      <div className={styles.container}>
        {/* Breadcrumb */}
        <nav className={styles.breadcrumb}>
          <Link href="/ar">الرئيسية</Link>
          <span>›</span>
          <Link href={`/ar?category=${ad.category?.id}`}>{ad.category?.name_ar}</Link>
          <span>›</span>
          <span>{ad.title}</span>
        </nav>

        <div className={styles.layout}>
          {/* ── Left: Main Content ── */}
          <div className={styles.leftCol}>

            <div className={styles.detailsCard}>
              {/* Title */}
              <h1 className={styles.desktopTitle}>{ad.title}</h1>

              {/* Meta */}
              <div className={styles.desktopMeta}>
                <span>📍 {ad.city?.name_ar || 'السعودية'}</span>
                <span>🕐 {relativeTime(ad.published_at)}</span>
              </div>

              {/* Seller */}
              {ad.user && (
                <div className={styles.desktopSellerRow}>
                  <div className={styles.desktopSellerInfo}>
                    <div className={styles.desktopSellerAvatar}>
                      {ad.user.avatar ? (
                        /* eslint-disable-next-line @next/next/no-img-element */
                        <img src={ad.user.avatar} alt={ad.user.name} />
                      ) : (
                        <span>{ad.user.name.charAt(0)}</span>
                      )}
                    </div>
                    <span className={styles.desktopSellerName}>{ad.user.name}</span>
                  </div>
                  <button className={styles.followBtn} onClick={() => requireAuth('follow')}>متابعة</button>
                </div>
              )}

              {/* Specs */}
              {ad.field_values && ad.field_values.length > 0 && (
                <div className={styles.desktopDescWrapper}>
                  <strong>— المواصفات :</strong><br />
                  {ad.field_values.map((fv) => (
                    <span key={fv.field_key}>* {fv.label_ar}: {String(fv.value)}<br /></span>
                  ))}
                </div>
              )}

              {/* Description */}
              <div className={styles.desktopDescWrapper}>
                {ad.description}
              </div>

              {/* Contact info embedded in text like Haraj */}
              <div className={styles.desktopDescWrapper} style={{ fontWeight: 600, marginBottom: 0 }}>
                للتواصل:<br />
                {ad.contact_phone}
              </div>
            </div>

            {/* Image carousel */}
            <div className={styles.carousel}>
              {ad.images && ad.images.length > 0 ? (
                <>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={ad.images[activeImg]?.image_url}
                    alt={ad.title}
                    className={styles.mainImg}
                    onClick={() => setLightboxOpen(true)}
                  />
                  <div className={styles.imgOverlay}>
                    <span className={styles.imgCounter}>{activeImg + 1} / {ad.images.length}</span>
                    <button className={styles.expandBtn} onClick={() => setLightboxOpen(true)} title="عرض مكبّر">⛶</button>
                  </div>
                  {ad.images.length > 1 && (
                    <div className={styles.thumbRow}>
                      {ad.images.map((img, i) => (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          key={img.id}
                          src={img.thumbnail_url}
                          alt=""
                          className={`${styles.thumb} ${activeImg === i ? styles.thumbActive : ''}`}
                          onClick={() => setActiveImg(i)}
                        />
                      ))}
                    </div>
                  )}
                </>
              ) : (
                <>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={`/images/${['car.jpg', 'fridge.jpeg', 'labtop.webp', 'mobile.jpeg'][ad.id % 4]}`}
                    alt={ad.title}
                    className={styles.mainImg}
                  />
                </>
              )}
            </div>

            {/* ── Haraj-Style Action Bar ── */}
            <div className={styles.hzContainer}>
              <div className={styles.hzCard}>
                  <button className={styles.hzContactBtn} onClick={() => window.location.href = `tel:${ad.contact_phone}`}>
                    <svg viewBox="0 0 24 24"><path d="M6.62 10.79a15.091 15.091 0 006.59 6.59l2.2-2.2a1 1 0 011.11-.27c1.12.37 2.33.57 3.58.57a1 1 0 011 1V20a1 1 0 01-1 1A19.93 19.93 0 012 2a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.46.57 3.58a1 1 0 01-.27 1.11l-2.2 2.2z"/></svg>
                    تواصل
                  </button>
              </div>

              <div className={styles.hzCard}>
                  <div className={styles.hzActionRow}>
                     <button className={styles.hzActionBtn} onClick={() => requireAuth('chat')}>
                        <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/></svg>
                        مراسلة
                     </button>
                     <button className={styles.hzActionBtn} onClick={() => requireAuth('favorite')}>
                        <svg viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>
                        تفضيل
                     </button>
                     <button className={styles.hzActionBtn} onClick={() => requireAuth('share')}>
                        <svg viewBox="0 0 24 24"><path d="M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92 1.61 0 2.92-1.31 2.92-2.92s-1.31-2.92-2.92-2.92z"/></svg>
                        مشاركة
                     </button>
                     <button className={styles.hzActionBtn} onClick={() => requireAuth('report')}>
                        <svg viewBox="0 0 24 24"><path d="M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z"/></svg>
                        بلاغ
                     </button>
                  </div>
              </div>

              <div className={styles.hzCard}>
                  <div className={styles.hzTagsRow}>
                    <Link href={`/${locale}`} className={styles.hzTag}>كل الحراج</Link>
                    {ad.category && <Link href={`/${locale}?category=${ad.category.id}`} className={styles.hzTag}>{ad.category.name_ar}</Link>}
                    {ad.city && <Link href={`/${locale}?city=${ad.city.id}`} className={styles.hzTag}>{ad.city.name_ar}</Link>}
                  </div>
              </div>

              <div className={styles.hzWarningBanner}>
                  <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 4c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm0 14c-2.03 0-4.43-.82-6.14-2.88a9.947 9.947 0 0112.28 0C16.43 19.18 14.03 20 12 20z"/></svg>
                  <span>شاهد ملف العضو وتقييماته والاراء حوله قبل التعامل معه.</span>
              </div>
            </div>

            {/* ── Comments / Questions Section ── */}
            <div className={styles.commentsSection}>
               {/* Mock Comment */}
               <div className={styles.commentCard}>
                 <div className={styles.commentIndex}>01</div>
                 <div className={styles.commentContent}>
                   <div className={styles.commentHeader}>
                     <div className={styles.commentUser}>
                        <svg width="18" height="18" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
                        <span>علي إبراهيم</span>
                     </div>
                     <span className={styles.commentTime}>الاسبوع الماضي</span>
                   </div>
                   <div className={styles.commentText}>
                     110 مع جميع مستحقاته
                   </div>
                   <button className={styles.commentReplyBtn} onClick={() => requireAuth('reply')}>
                     <svg width="14" height="14" fill="currentColor" viewBox="0 0 24 24"><path d="M10 9V5l-7 7 7 7v-4.1c5 0 8.5 1.6 11 5.1-1-5-4-10-11-11z"/></svg>
                     الرد
                   </button>
                 </div>
               </div>

               {/* New Comment Textarea */}
               <div className={styles.newCommentCard}>
                 <textarea 
                   className={styles.newCommentTextarea} 
                   placeholder="اكتب سؤالك للعارض هنا"
                 ></textarea>
                 <div className={styles.newCommentFooter}>
                   <button className={styles.sendCommentBtn} onClick={() => requireAuth('comment')}>
                     إرسال
                     <svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
                   </button>
                 </div>
               </div>
            </div>

            {/* Disclaimer */}
            <div className={styles.disclaimer} style={{ marginTop: '1.5rem' }}>
              <span className={styles.disclaimerIcon}>⚠️</span>
              <p>
                <strong>تنبيه:</strong> برق واضح هي منصة وسيطة بين البائع والمشتري. الموقع غير مسؤول عن دقة المعلومات المقدمة من المُعلن.
                يُرجى التحقق من السلعة قبل إتمام الصفقة، وعدم دفع أي مبالغ مقدماً دون التأكد من الجودة.
              </p>
            </div>
          </div>

          {/* ── Right: Sidebar (Similar Ads) ── */}
          <div className={styles.rightCol}>
            <div className={styles.similarSidebar}>
              <button className={styles.similarHeaderBtn} onClick={() => requireAuth('follow_ads')}>
                <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
                  <path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/>
                </svg>
                متابعة العروض المشابهة
              </button>
              
              <div className={styles.similarTabs}>
                <button className={styles.similarTabActive}>عروض مشابهة</button>
                <button className={styles.similarTab}>
                  {ad.category?.name_ar} {ad.city ? `في ${ad.city.name_ar}` : ''}
                </button>
              </div>

              {similarAds.length > 0 ? (
                <div className={styles.similarGrid}>
                  {similarAds.map(s => (
                    <Link href={`/${locale}/ads/${s.id}`} key={s.id} className={styles.similarCard}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img 
                        src={s.primary_image?.thumbnail_url || '/images/car.jpg'} 
                        alt={s.title} 
                        className={styles.similarImg} 
                      />
                      <div className={styles.similarTitle}>{s.title}</div>
                    </Link>
                  ))}
                </div>
              ) : (
                <p style={{ fontSize: '0.85rem', color: 'var(--text-tertiary)', textAlign: 'center', marginTop: '1rem' }}>
                  لا توجد عروض مشابهة
                </p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* ── Lightbox ── */}
      {lightboxOpen && (
        <div className={styles.lightboxOverlay} onClick={() => setLightboxOpen(false)}>
          <button className={styles.lightboxClose} onClick={() => setLightboxOpen(false)}>✕</button>
          {ad.images.length > 1 && (
            <>
              <button
                className={`${styles.lightboxNav} ${styles.lightboxPrev}`}
                onClick={e => { e.stopPropagation(); setActiveImg(i => (i - 1 + ad.images.length) % ad.images.length); }}
              >
                ‹
              </button>
              <button
                className={`${styles.lightboxNav} ${styles.lightboxNext}`}
                onClick={e => { e.stopPropagation(); setActiveImg(i => (i + 1) % ad.images.length); }}
              >
                ›
              </button>
            </>
          )}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={ad.images[activeImg]?.image_url}
            alt={ad.title}
            className={styles.lightboxImg}
            onClick={e => e.stopPropagation()}
          />
          <div className={styles.lightboxCounter}>{activeImg + 1} / {ad.images.length}</div>
        </div>
      )}

      {/* ── Share toast ── */}
      {shareToast && (
        <div className={styles.shareToast}>✓ تم نسخ رابط الإعلان</div>
      )}

      {/* ── Rating Modal ── */}
      {showRatingModal && ad?.user && (
        <RatingModal
          adId={ad.id}
          sellerName={ad.user.name}
          onClose={() => setShowRatingModal(false)}
          onSuccess={() => setShowRatingModal(false)}
        />
      )}

      {/* ── Report Modal ── */}
      {showReportModal && (
        <ReportModal
          adId={ad.id}
          onClose={() => setShowReportModal(false)}
        />
      )}

      {/* ── Auth Modal ── */}
      <AuthModal
        isOpen={showAuthModal}
        onClose={() => setShowAuthModal(false)}
        onSuccess={handleAuthSuccess}
      />
    </>
  );
}
