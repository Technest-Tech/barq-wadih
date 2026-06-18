'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import {
  fetchAdminUsers,
  updateUserStatus,
  type AdminUser,
  type AdminUserFilters,
} from '@/lib/api/admin';
import styles from './users.module.css';

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

export default function AdminUsersPage() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, per_page: 20, total: 0 });
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<AdminUserFilters>({ sort: 'created_at', dir: 'desc' });
  const [searchQuery, setSearchQuery] = useState('');
  const [toast, setToast] = useState<Toast | null>(null);
  const [modal, setModal] = useState<ConfirmModal | null>(null);
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [navigatingTo, setNavigatingTo] = useState<number | null>(null);
  const router = useRouter();

  const loadUsers = useCallback(
    async (overrideFilters?: AdminUserFilters) => {
      setLoading(true);
      try {
        const activeFilters = overrideFilters || filters;
        const response = await fetchAdminUsers(activeFilters);
        setUsers(response.data);
        setMeta(response.meta);
      } catch (err) {
        showToast(err instanceof Error ? err.message : 'فشل تحميل المستخدمين', 'error');
      } finally {
        setLoading(false);
      }
    },
    [filters]
  );

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  // Real-time search with 400ms debounce
  useEffect(() => {
    const timer = setTimeout(() => {
      const newFilters = { ...filters, q: searchQuery || undefined, page: 1 };
      setFilters(newFilters);
      loadUsers(newFilters);
    }, 400);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery]);

  const showToast = (message: string, type: 'success' | 'error') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  const handleFilterChange = (key: keyof AdminUserFilters, value: string) => {
    const newFilters = { ...filters, [key]: value || undefined, page: 1 };
    setFilters(newFilters);
    loadUsers(newFilters);
  };

  const handleSort = (field: string) => {
    const newDir = filters.sort === field && filters.dir === 'desc' ? 'asc' : 'desc';
    const newFilters = { ...filters, sort: field, dir: newDir, page: 1 };
    setFilters(newFilters);
    loadUsers(newFilters);
  };

  const handlePageChange = (page: number) => {
    const newFilters = { ...filters, page };
    setFilters(newFilters);
    loadUsers(newFilters);
  };

  const clearFilters = () => {
    const newFilters: AdminUserFilters = { sort: 'created_at', dir: 'desc' };
    setSearchQuery('');
    setFilters(newFilters);
    loadUsers(newFilters);
  };

  const handleToggleStatus = (user: AdminUser) => {
    const action = user.is_active ? 'تعطيل' : 'تفعيل';
    setModal({
      title: `${action} الحساب`,
      body: `هل أنت متأكد من ${action} حساب "${user.name}"؟`,
      type: user.is_active ? 'danger' : 'confirm',
      onConfirm: async () => {
        setModal(null);
        setActionLoading(user.id);
        try {
          await updateUserStatus(user.id, !user.is_active);
          showToast(`تم ${action} الحساب بنجاح`, 'success');
          loadUsers();
        } catch (err) {
          showToast(err instanceof Error ? err.message : 'فشلت العملية', 'error');
        } finally {
          setActionLoading(null);
        }
      },
    });
  };

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('ar-SA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const activeFiltersCount = [
    filters.q,
    filters.role,
    filters.is_active,
    filters.is_verified,
  ].filter(Boolean).length;

  const getSortArrow = (field: string) => {
    if (filters.sort !== field) return '';
    return filters.dir === 'asc' ? '↑' : '↓';
  };

  return (
    <div className={styles.page}>
      {/* Navigation loading overlay */}
      {navigatingTo !== null && (
        <div className={styles.navOverlay}>
          <div className={styles.navSpinnerWrap}>
            <div className={styles.navSpinner} />
            <span className={styles.navSpinnerLabel}>جاري التحميل...</span>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && <div className={`${styles.toast} ${styles[toast.type]}`}>{toast.message}</div>}

      {/* Confirm Modal */}
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

      {/* Header */}
      <div className={styles.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <h1 className={styles.pageTitle}>إدارة المستخدمين</h1>
          <span className={styles.totalBadge}>{meta.total} مستخدم</span>
        </div>
      </div>

      {/* Filter Bar */}
      <div className={styles.filterBar}>
        <div className={styles.searchRow}>
          <div className={styles.searchWrap}>
            <svg
              className={styles.searchIcon}
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              className={styles.searchInput}
              type="text"
              placeholder="بحث بالاسم، البريد، أو الهاتف..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <select
            className={styles.select}
            value={filters.role || ''}
            onChange={(e) => handleFilterChange('role', e.target.value)}
          >
            <option value="">كل الأدوار</option>
            <option value="user">مستخدم</option>
            <option value="admin">مشرف</option>
            <option value="super_admin">مشرف عام</option>
          </select>
        </div>

        <div className={styles.filterChips}>
          <button
            className={`${styles.chip} ${!filters.is_active ? styles.active : ''}`}
            onClick={() => handleFilterChange('is_active', '')}
          >
            الكل
          </button>
          <button
            className={`${styles.chip} ${filters.is_active === '1' ? styles.active : ''}`}
            onClick={() => handleFilterChange('is_active', filters.is_active === '1' ? '' : '1')}
          >
            ✅ نشط
          </button>
          <button
            className={`${styles.chip} ${filters.is_active === '0' ? styles.active : ''}`}
            onClick={() => handleFilterChange('is_active', filters.is_active === '0' ? '' : '0')}
          >
            ⛔ معطل
          </button>

          <span className={styles.chipDivider} />

          <button
            className={`${styles.chip} ${filters.is_verified === '1' ? styles.active : ''}`}
            onClick={() =>
              handleFilterChange('is_verified', filters.is_verified === '1' ? '' : '1')
            }
          >
            🛡️ موثق
          </button>

          {activeFiltersCount > 0 && (
            <button className={styles.clearBtn} onClick={clearFilters}>
              ✕ مسح الفلاتر
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className={styles.loading}>
          <div className={styles.loadingSpinner} />
          <span>جاري تحميل المستخدمين...</span>
        </div>
      ) : users.length === 0 ? (
        <div className={styles.emptyState}>
          <h3>لا توجد نتائج</h3>
          <p>جرب تغيير معايير البحث أو الفلاتر</p>
        </div>
      ) : (
        <div className={styles.tableCard}>
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th
                    onClick={() => handleSort('name')}
                    className={filters.sort === 'name' ? styles.sorted : ''}
                  >
                    <span className={styles.sortArrow}>{getSortArrow('name')}</span> الاسم
                  </th>
                  <th>رقم الهاتف</th>
                  <th>الدور</th>
                  <th>الحالة</th>
                  <th>الموقع</th>
                  <th
                    onClick={() => handleSort('total_ads_count')}
                    className={filters.sort === 'total_ads_count' ? styles.sorted : ''}
                  >
                    <span className={styles.sortArrow}>{getSortArrow('total_ads_count')}</span>{' '}
                    الإعلانات
                  </th>
                  <th
                    onClick={() => handleSort('avg_rating')}
                    className={filters.sort === 'avg_rating' ? styles.sorted : ''}
                  >
                    <span className={styles.sortArrow}>{getSortArrow('avg_rating')}</span> التقييم
                  </th>
                  <th
                    onClick={() => handleSort('created_at')}
                    className={filters.sort === 'created_at' ? styles.sorted : ''}
                  >
                    <span className={styles.sortArrow}>{getSortArrow('created_at')}</span> التسجيل
                  </th>
                  <th>إجراءات</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div className={styles.userCell}>
                        {user.avatar_url ? (
                          <img src={user.avatar_url} alt="" className={styles.userAvatarImg} />
                        ) : (
                          <div className={styles.userAvatar}>{user.name?.[0] || '?'}</div>
                        )}
                        <span className={styles.userName}>
                          {user.name}
                          {user.is_verified && <span className={styles.verifiedBadge}> ✓</span>}
                        </span>
                      </div>
                    </td>
                    <td>
                      <span className={styles.phoneValue}>{user.phone || '—'}</span>
                    </td>
                    <td>
                      <span className={`${styles.roleBadge} ${styles[user.role]}`}>
                        {user.role_label}
                      </span>
                    </td>
                    <td>
                      <span className={styles.statusDot}>
                        <span
                          className={`${styles.dot} ${user.is_active ? styles.green : styles.red}`}
                        />
                        {user.is_active ? 'نشط' : 'معطل'}
                      </span>
                    </td>
                    <td>{user.city?.name_ar || user.region?.name_ar || '—'}</td>
                    <td>{user.total_ads_count}</td>
                    <td>
                      <div className={styles.ratingCell}>
                        <span className={styles.star}>★</span>
                        {parseFloat(user.avg_rating || '0').toFixed(1)}
                        <span style={{ color: 'var(--admin-text-muted)', fontSize: '11px' }}>
                          ({user.rating_count})
                        </span>
                      </div>
                    </td>
                    <td className={styles.dateCell}>{formatDate(user.created_at)}</td>
                    <td>
                      <div className={styles.actions}>
                        <button
                          className={`${styles.actionBtn} ${styles.view}`}
                          onClick={() => {
                            setNavigatingTo(user.id);
                            router.push(`/admin/users/${user.id}`);
                          }}
                        >
                          عرض
                        </button>
                        <button
                          className={`${styles.actionBtn} ${styles.toggle}`}
                          onClick={() => handleToggleStatus(user)}
                          disabled={actionLoading === user.id}
                        >
                          {actionLoading === user.id ? '...' : user.is_active ? 'تعطيل' : 'تفعيل'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className={styles.pagination}>
            <span className={styles.paginationInfo}>
              عرض {(meta.current_page - 1) * meta.per_page + 1} -{' '}
              {Math.min(meta.current_page * meta.per_page, meta.total)} من {meta.total}
            </span>
            <div className={styles.paginationBtns}>
              <button
                className={styles.pageBtn}
                disabled={meta.current_page <= 1}
                onClick={() => handlePageChange(meta.current_page - 1)}
              >
                السابق
              </button>
              {Array.from({ length: Math.min(meta.last_page, 5) }, (_, i) => {
                let pageNum: number;
                if (meta.last_page <= 5) {
                  pageNum = i + 1;
                } else if (meta.current_page <= 3) {
                  pageNum = i + 1;
                } else if (meta.current_page >= meta.last_page - 2) {
                  pageNum = meta.last_page - 4 + i;
                } else {
                  pageNum = meta.current_page - 2 + i;
                }
                return (
                  <button
                    key={pageNum}
                    className={`${styles.pageBtn} ${meta.current_page === pageNum ? styles.active : ''}`}
                    onClick={() => handlePageChange(pageNum)}
                  >
                    {pageNum}
                  </button>
                );
              })}
              <button
                className={styles.pageBtn}
                disabled={meta.current_page >= meta.last_page}
                onClick={() => handlePageChange(meta.current_page + 1)}
              >
                التالي
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
