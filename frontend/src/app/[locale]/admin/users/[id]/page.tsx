'use client';

import { useEffect, useState, use } from 'react';
import Link from 'next/link';
import {
  fetchAdminUser,
  updateUserStatus,
  updateUserRole,
  type AdminUserDetail,
} from '@/lib/api/admin';
import styles from './user-detail.module.css';

interface Toast {
  message: string;
  type: 'success' | 'error';
}

interface ConfirmModal {
  title: string;
  body: string;
  type: 'confirm' | 'danger';
  onConfirm: () => void;
}

export default function AdminUserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [user, setUser] = useState<AdminUserDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'ads' | 'payments' | 'ratings'>('ads');
  const [toast, setToast] = useState<Toast | null>(null);
  const [modal, setModal] = useState<ConfirmModal | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const loadUser = async () => {
    setLoading(true);
    try {
      const data = await fetchAdminUser(Number(id));
      setUser(data);
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'فشل تحميل بيانات المستخدم', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUser();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const showToast = (message: string, type: 'success' | 'error') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString('ar-SA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const handleToggleStatus = () => {
    if (!user) return;
    const action = user.is_active ? 'تعطيل' : 'تفعيل';
    setModal({
      title: `${action} الحساب`,
      body: `هل أنت متأكد من ${action} حساب "${user.name}"؟ ${user.is_active ? 'لن يتمكن المستخدم من تسجيل الدخول.' : ''}`,
      type: user.is_active ? 'danger' : 'confirm',
      onConfirm: async () => {
        setModal(null);
        setActionLoading(true);
        try {
          await updateUserStatus(user.id, !user.is_active);
          showToast(`تم ${action} الحساب بنجاح`, 'success');
          loadUser();
        } catch (err) {
          showToast(err instanceof Error ? err.message : 'فشلت العملية', 'error');
        } finally {
          setActionLoading(false);
        }
      },
    });
  };

  const handleRoleChange = async (newRole: string) => {
    if (!user || newRole === user.role) return;
    setActionLoading(true);
    try {
      await updateUserRole(user.id, newRole);
      showToast('تم تحديث الصلاحيات بنجاح', 'success');
      loadUser();
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'فشل تحديث الصلاحيات', 'error');
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <div className={styles.loading}>
        <div className={styles.loadingSpinner} />
        <span>جاري تحميل بيانات المستخدم...</span>
      </div>
    );
  }

  if (!user) {
    return (
      <div className={styles.loading}>
        <h3>⚠️ لم يتم العثور على المستخدم</h3>
        <Link href="/admin/users" className={styles.backLink}>
          ← العودة للمستخدمين
        </Link>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      {/* Toast */}
      {toast && <div className={`${styles.toast} ${styles[toast.type]}`}>{toast.message}</div>}

      {/* Modal */}
      {modal && (
        <div className={styles.modalOverlay} onClick={() => setModal(null)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <h3 className={styles.modalTitle}>{modal.title}</h3>
            <p className={styles.modalBody}>{modal.body}</p>
            <div className={styles.modalActions}>
              <button
                className={`${styles.modalBtn} ${styles[modal.type]}`}
                onClick={modal.onConfirm}
              >
                تأكيد
              </button>
              <button
                className={`${styles.modalBtn} ${styles.cancel}`}
                onClick={() => setModal(null)}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Back */}
      <Link href="/admin/users" className={styles.backLink}>
        → العودة للمستخدمين
      </Link>

      {/* Profile Card */}
      <div className={styles.profileCard}>
        <div className={styles.profileHeader}>
          {user.avatar_url ? (
            <img src={user.avatar_url} alt="" className={styles.profileAvatarImg} />
          ) : (
            <div className={styles.profileAvatar}>{user.name?.[0] || '?'}</div>
          )}

          <div className={styles.profileInfo}>
            <h1 className={styles.profileName}>{user.name}</h1>

            <div className={styles.profileBadges}>
              <span className={`${styles.badge} ${styles.role}`}>{user.role_label}</span>
              <span
                className={`${styles.badge} ${user.is_active ? styles.active : styles.inactive}`}
              >
                {user.is_active ? '✅ نشط' : '⛔ معطل'}
              </span>
              {user.is_verified && (
                <span className={`${styles.badge} ${styles.verified}`}>🛡️ موثق</span>
              )}
            </div>

            <div className={styles.profileMeta}>
              {user.phone && <span className={styles.metaItem}>📱 {user.phone}</span>}
              {user.email && <span className={styles.metaItem}>📧 {user.email}</span>}
              {user.city && <span className={styles.metaItem}>📍 {user.city.name_ar}</span>}
              <span className={styles.metaItem}>📅 انضم {formatDate(user.created_at)}</span>
              {user.last_active_at && (
                <span className={styles.metaItem}>
                  🕐 آخر نشاط {formatDate(user.last_active_at)}
                </span>
              )}
            </div>
          </div>

          <div className={styles.profileActions}>
            <select
              className={styles.roleSelect}
              value={user.role}
              onChange={(e) => handleRoleChange(e.target.value)}
              disabled={actionLoading}
            >
              <option value="user">مستخدم</option>
              <option value="admin">مشرف</option>
              <option value="super_admin">مشرف عام</option>
            </select>
            <button
              className={`${styles.profileBtn} ${user.is_active ? styles.danger : styles.primary}`}
              onClick={handleToggleStatus}
              disabled={actionLoading}
            >
              {user.is_active ? '⛔ تعطيل الحساب' : '✅ تفعيل الحساب'}
            </button>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className={styles.statsGrid}>
        <div className={styles.statCard}>
          <div className={styles.statValue}>{user.total_ads_count}</div>
          <div className={styles.statLabel}>إجمالي الإعلانات</div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statValue}>★ {parseFloat(user.avg_rating || '0').toFixed(1)}</div>
          <div className={styles.statLabel}>التقييم ({user.rating_count} تقييم)</div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statValue}>{user.commissions_paid_count}</div>
          <div className={styles.statLabel}>عمولات مدفوعة</div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statValue}>{user.commissions_due_count}</div>
          <div className={styles.statLabel}>عمولات معلقة</div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statValue}>{user.devices_count || 0}</div>
          <div className={styles.statLabel}>أجهزة مسجلة</div>
        </div>
      </div>

      {/* Tabs */}
      <div className={styles.tabsHeader}>
        <button
          className={`${styles.tab} ${activeTab === 'ads' ? styles.active : ''}`}
          onClick={() => setActiveTab('ads')}
        >
          📋 الإعلانات
          <span className={styles.tabBadge}>{user.ads?.length || 0}</span>
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'payments' ? styles.active : ''}`}
          onClick={() => setActiveTab('payments')}
        >
          💰 المدفوعات
          <span className={styles.tabBadge}>{user.commission_payments?.length || 0}</span>
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'ratings' ? styles.active : ''}`}
          onClick={() => setActiveTab('ratings')}
        >
          ⭐ التقييمات
          <span className={styles.tabBadge}>{user.ratings_received?.length || 0}</span>
        </button>
      </div>

      <div className={styles.tabContent}>
        {/* Ads Tab */}
        {activeTab === 'ads' && (
          <div className={styles.tableWrap}>
            {user.ads && user.ads.length > 0 ? (
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>#</th>
                    <th>العنوان</th>
                    <th>التصنيف</th>
                    <th>المدينة</th>
                    <th>السعر</th>
                    <th>المشاهدات</th>
                    <th>الحالة</th>
                    <th>التاريخ</th>
                  </tr>
                </thead>
                <tbody>
                  {user.ads.map((ad) => (
                    <tr key={ad.id}>
                      <td style={{ color: 'var(--admin-text-muted)' }}>{ad.id}</td>
                      <td style={{ color: 'var(--admin-text)', fontWeight: 600 }}>{ad.title}</td>
                      <td>{ad.category?.name_ar || '—'}</td>
                      <td>{ad.city?.name_ar || '—'}</td>
                      <td style={{ fontWeight: 700, direction: 'ltr', textAlign: 'start' }}>
                        {ad.price > 0 ? `${ad.price.toLocaleString('ar-SA')} ر.س` : 'مجاني'}
                      </td>
                      <td>{ad.views_count}</td>
                      <td>
                        <span className={`${styles.statusBadge} ${styles[ad.status] || ''}`}>
                          {ad.status_label}
                        </span>
                      </td>
                      <td
                        style={{
                          fontSize: '12px',
                          color: 'var(--admin-text-muted)',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {formatDate(ad.created_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className={styles.emptyTab}>لا توجد إعلانات لهذا المستخدم</div>
            )}
          </div>
        )}

        {/* Payments Tab */}
        {activeTab === 'payments' && (
          <div className={styles.tableWrap}>
            {user.commission_payments && user.commission_payments.length > 0 ? (
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>#</th>
                    <th>المبلغ</th>
                    <th>الحالة</th>
                    <th>طريقة الدفع</th>
                    <th>رقم الإعلان</th>
                    <th>تاريخ الدفع</th>
                    <th>تاريخ الإنشاء</th>
                  </tr>
                </thead>
                <tbody>
                  {user.commission_payments.map((payment) => (
                    <tr key={payment.id}>
                      <td style={{ color: 'var(--admin-text-muted)' }}>{payment.id}</td>
                      <td style={{ fontWeight: 700, direction: 'ltr', textAlign: 'start' }}>
                        {payment.amount.toLocaleString('ar-SA')} ر.س
                      </td>
                      <td>
                        <span className={`${styles.statusBadge} ${styles[payment.status] || ''}`}>
                          {payment.status === 'paid'
                            ? 'مدفوع'
                            : payment.status === 'due'
                              ? 'مستحق'
                              : payment.status}
                        </span>
                      </td>
                      <td>{payment.payment_method || '—'}</td>
                      <td>{payment.ad_id || '—'}</td>
                      <td style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>
                        {formatDate(payment.paid_at)}
                      </td>
                      <td style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>
                        {formatDate(payment.created_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className={styles.emptyTab}>لا توجد مدفوعات لهذا المستخدم</div>
            )}
          </div>
        )}

        {/* Ratings Tab */}
        {activeTab === 'ratings' && (
          <div className={styles.tableWrap}>
            {user.ratings_received && user.ratings_received.length > 0 ? (
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th>المُقيّم</th>
                    <th>التقييم</th>
                    <th>التعليق</th>
                    <th>التاريخ</th>
                  </tr>
                </thead>
                <tbody>
                  {user.ratings_received.map((rating) => (
                    <tr key={rating.id}>
                      <td style={{ color: 'var(--admin-text)', fontWeight: 600 }}>
                        {rating.rater?.name || 'مجهول'}
                      </td>
                      <td>
                        <span className={styles.ratingStars}>
                          {'★'.repeat(rating.score)}
                          {'☆'.repeat(5 - rating.score)}
                        </span>
                      </td>
                      <td>
                        {rating.comment ? (
                          <div className={styles.ratingComment}>&quot;{rating.comment}&quot;</div>
                        ) : (
                          <span style={{ color: 'var(--admin-text-muted)' }}>—</span>
                        )}
                      </td>
                      <td style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>
                        {formatDate(rating.created_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className={styles.emptyTab}>لا توجد تقييمات لهذا المستخدم</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
