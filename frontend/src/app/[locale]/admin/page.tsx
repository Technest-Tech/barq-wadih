'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Bar, Doughnut, Line } from 'react-chartjs-2';
import { fetchDashboardStats, type DashboardStats } from '@/lib/api/admin';
import styles from './dashboard.module.css';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Tooltip,
  Legend,
  Filler
);

// Chart.js global defaults for dark theme
ChartJS.defaults.color = '#94a3b8';
ChartJS.defaults.borderColor = 'rgba(255, 255, 255, 0.06)';
ChartJS.defaults.font.family = "'Inter', 'Noto Sans Arabic', system-ui, sans-serif";

function formatNumber(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toLocaleString('ar-SA');
}

function formatCurrency(n: number): string {
  return `${n.toLocaleString('ar-SA')} ر.س`;
}

function getTrendInfo(current: number, previous: number) {
  if (previous === 0) return { dir: 'neutral' as const, pct: '—' };
  const diff = ((current - previous) / previous) * 100;
  if (diff > 0) return { dir: 'up' as const, pct: `+${diff.toFixed(0)}%` };
  if (diff < 0) return { dir: 'down' as const, pct: `${diff.toFixed(0)}%` };
  return { dir: 'neutral' as const, pct: '0%' };
}

function timeAgo(dateStr: string): string {
  const now = new Date();
  const date = new Date(dateStr);
  const secs = Math.floor((now.getTime() - date.getTime()) / 1000);
  if (secs < 60) return 'الآن';
  const mins = Math.floor(secs / 60);
  if (mins < 60) return `منذ ${mins} دقيقة`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `منذ ${hours} ساعة`;
  const days = Math.floor(hours / 24);
  return `منذ ${days} يوم`;
}

export default function AdminDashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const loadStats = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);
    setError('');

    try {
      const data = await fetchDashboardStats();
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'فشل تحميل البيانات');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  if (loading) {
    return (
      <div className={styles.loading}>
        <div className={styles.loadingSpinner} />
        <span>جاري تحميل لوحة التحكم...</span>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className={styles.errorState}>
        <h2>⚠️ خطأ في التحميل</h2>
        <p>{error || 'لم يتم استلام البيانات'}</p>
        <button className={styles.retryBtn} onClick={() => loadStats()}>
          إعادة المحاولة
        </button>
      </div>
    );
  }

  const userTrend = getTrendInfo(stats.users.new_this_month, stats.users.new_prev_month);
  const revenueTrend = getTrendInfo(stats.revenue.this_month, stats.revenue.prev_month);

  // ── Chart Data ──────────────────────────────────────────────────────────
  const registrationChartData = {
    labels: stats.users.weekly_registrations.map((w) => w.week),
    datasets: [
      {
        label: 'المستخدمين الجدد',
        data: stats.users.weekly_registrations.map((w) => w.count),
        fill: true,
        backgroundColor: 'rgba(99, 102, 241, 0.1)',
        borderColor: '#6366f1',
        borderWidth: 2,
        pointBackgroundColor: '#6366f1',
        pointBorderColor: '#ffffff',
        pointBorderWidth: 2,
        pointRadius: 4,
        pointHoverRadius: 6,
        tension: 0.4,
      },
    ],
  };

  const revenueChartData = {
    labels: stats.revenue.monthly.map((m) => m.month),
    datasets: [
      {
        label: 'الإيرادات (ر.س)',
        data: stats.revenue.monthly.map((m) => m.revenue),
        backgroundColor: 'rgba(34, 197, 94, 0.7)',
        borderColor: '#22c55e',
        borderWidth: 1,
        borderRadius: 6,
        borderSkipped: false,
      },
    ],
  };

  const adsByStatusData = {
    labels: stats.ads.by_status.map((s) => s.label),
    datasets: [
      {
        data: stats.ads.by_status.map((s) => s.count),
        backgroundColor: [
          '#22c55e', // active
          '#3b82f6', // sold
          '#94a3b8', // expired
          '#f59e0b', // pending
          '#ef4444', // rejected
          '#8b5cf6', // draft
        ],
        borderWidth: 0,
        hoverOffset: 8,
      },
    ],
  };

  const usersByRoleData = {
    labels: stats.users.by_role.map((r) => r.label),
    datasets: [
      {
        data: stats.users.by_role.map((r) => r.count),
        backgroundColor: ['#6366f1', '#f59e0b', '#ef4444'],
        borderWidth: 0,
        hoverOffset: 8,
      },
    ],
  };

  const lineOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: '#ffffff',
        titleColor: '#0f172a',
        bodyColor: '#475569',
        borderColor: 'rgba(0,0,0,0.1)',
        borderWidth: 1,
        padding: 12,
        cornerRadius: 8,
        rtl: true,
        textDirection: 'rtl' as const,
      },
    },
    scales: {
      x: {
        grid: { display: false },
        ticks: { font: { size: 11 } },
      },
      y: {
        grid: { color: 'rgba(255,255,255,0.04)' },
        ticks: { font: { size: 11 } },
        beginAtZero: true,
      },
    },
  };

  const barOptions = {
    ...lineOptions,
    plugins: {
      ...lineOptions.plugins,
      legend: { display: false },
    },
  };

  const doughnutOptions = {
    responsive: true,
    maintainAspectRatio: false,
    cutout: '70%',
    plugins: {
      legend: {
        position: 'bottom' as const,
        rtl: true,
        labels: {
          padding: 16,
          usePointStyle: true,
          pointStyleWidth: 10,
          font: { size: 12 },
        },
      },
      tooltip: {
        backgroundColor: '#ffffff',
        titleColor: '#0f172a',
        bodyColor: '#475569',
        borderColor: 'rgba(0,0,0,0.1)',
        borderWidth: 1,
        padding: 12,
        cornerRadius: 8,
        rtl: true,
        textDirection: 'rtl' as const,
      },
    },
  };

  const now = new Date();
  const dateStr = now.toLocaleDateString('ar-SA', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    <div className={styles.page}>
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className={styles.pageHeader}>
        <div>
          <h1 className={styles.pageTitle}>لوحة التحكم</h1>
          <p className={styles.pageDate}>{dateStr}</p>
        </div>
        <button
          className={styles.refreshBtn}
          onClick={() => loadStats(true)}
          disabled={refreshing}
        >
          <span className={`${styles.refreshIcon} ${refreshing ? styles.spinning : ''}`}>🔄</span>
          تحديث
        </button>
      </div>

      {/* ── KPI Cards ──────────────────────────────────────────────────── */}
      <div className={styles.kpiGrid}>
        {/* Total Users */}
        <div className={`${styles.kpiCard} ${styles.accent}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>👥</span>
            <span className={`${styles.kpiTrend} ${styles[userTrend.dir]}`}>
              {userTrend.dir === 'up' ? '↑' : userTrend.dir === 'down' ? '↓' : '—'} {userTrend.pct}
            </span>
          </div>
          <div className={styles.kpiValue}>{formatNumber(stats.users.total)}</div>
          <div className={styles.kpiLabel}>إجمالي المستخدمين</div>
          <div className={styles.kpiSub}>
            {stats.users.new_today} جديد اليوم • {stats.users.new_this_week} هذا الأسبوع
          </div>
        </div>

        {/* Active Ads */}
        <div className={`${styles.kpiCard} ${styles.success}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>📢</span>
          </div>
          <div className={styles.kpiValue}>{formatNumber(stats.ads.active)}</div>
          <div className={styles.kpiLabel}>إعلانات نشطة</div>
          <div className={styles.kpiSub}>
            {stats.ads.new_today} جديد اليوم • {formatNumber(stats.ads.total)} إجمالي
          </div>
        </div>

        {/* Revenue */}
        <div className={`${styles.kpiCard} ${styles.warning}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>💰</span>
            <span className={`${styles.kpiTrend} ${styles[revenueTrend.dir]}`}>
              {revenueTrend.dir === 'up' ? '↑' : revenueTrend.dir === 'down' ? '↓' : '—'} {revenueTrend.pct}
            </span>
          </div>
          <div className={styles.kpiValue}>{formatCurrency(stats.revenue.total)}</div>
          <div className={styles.kpiLabel}>إجمالي الإيرادات</div>
          <div className={styles.kpiSub}>
            {formatCurrency(stats.revenue.this_month)} هذا الشهر
          </div>
        </div>

        {/* Pending Commissions */}
        <div className={`${styles.kpiCard} ${styles.info}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>⏳</span>
          </div>
          <div className={styles.kpiValue}>{formatCurrency(stats.revenue.pending_commissions)}</div>
          <div className={styles.kpiLabel}>عمولات معلقة</div>
        </div>

        {/* Active Banners */}
        <div className={`${styles.kpiCard} ${styles.purple}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>🖼️</span>
          </div>
          <div className={styles.kpiValue}>{stats.banners.active}</div>
          <div className={styles.kpiLabel}>بانرات نشطة</div>
        </div>

        {/* Pending Reports */}
        <div className={`${styles.kpiCard} ${styles.danger}`}>
          <div className={styles.kpiHeader}>
            <span className={styles.kpiIcon}>⚠️</span>
          </div>
          <div className={styles.kpiValue}>{stats.reports.pending}</div>
          <div className={styles.kpiLabel}>بلاغات معلقة</div>
        </div>
      </div>

      {/* ── Quick Stats ────────────────────────────────────────────────── */}
      <div className={styles.quickStats}>
        <div className={styles.quickStat}>
          <span className={styles.quickStatIcon}>✅</span>
          <div>
            <div className={styles.quickStatValue}>{stats.users.active}</div>
            <div className={styles.quickStatLabel}>مستخدم نشط</div>
          </div>
        </div>
        <div className={styles.quickStat}>
          <span className={styles.quickStatIcon}>🛡️</span>
          <div>
            <div className={styles.quickStatValue}>{stats.users.verified}</div>
            <div className={styles.quickStatLabel}>موثق</div>
          </div>
        </div>
        <div className={styles.quickStat}>
          <span className={styles.quickStatIcon}>🏬</span>
          <div>
            <div className={styles.quickStatValue}>{stats.users.dealers}</div>
            <div className={styles.quickStatLabel}>تاجر</div>
          </div>
        </div>
        <div className={styles.quickStat}>
          <span className={styles.quickStatIcon}>📅</span>
          <div>
            <div className={styles.quickStatValue}>{stats.users.new_this_month}</div>
            <div className={styles.quickStatLabel}>جديد هذا الشهر</div>
          </div>
        </div>
      </div>

      {/* ── Charts ─────────────────────────────────────────────────────── */}
      <div className={styles.chartsGrid}>
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>📈 المستخدمين الجدد (12 أسبوع)</div>
          <div className={styles.chartWrapper}>
            <Line data={registrationChartData} options={lineOptions} />
          </div>
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>💵 الإيرادات الشهرية</div>
          <div className={styles.chartWrapper}>
            <Bar data={revenueChartData} options={barOptions} />
          </div>
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>📊 الإعلانات حسب الحالة</div>
          <div className={styles.chartWrapper}>
            <Doughnut data={adsByStatusData} options={doughnutOptions} />
          </div>
        </div>

        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>👤 المستخدمين حسب الدور</div>
          <div className={styles.chartWrapper}>
            <Doughnut data={usersByRoleData} options={doughnutOptions} />
          </div>
        </div>
      </div>

      {/* ── Recent Ads ─────────────────────────────────────────────────── */}
      <div className={styles.recentSection}>
        <div className={styles.sectionHeader}>
          <div className={styles.sectionTitle}>🕐 آخر الإعلانات</div>
          <Link href="/admin/ads" className={styles.viewAllLink}>
            عرض الكل →
          </Link>
        </div>
        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>المُعلن</th>
                <th>العنوان</th>
                <th>التصنيف</th>
                <th>السعر</th>
                <th>الحالة</th>
                <th>التاريخ</th>
              </tr>
            </thead>
            <tbody>
              {stats.recent_ads.map((ad) => (
                <tr key={ad.id}>
                  <td>
                    <div className={styles.userCell}>
                      <div className={styles.userAvatar}>
                        {ad.user?.name?.[0] || '?'}
                      </div>
                      <span className={styles.userName}>{ad.user?.name || 'مجهول'}</span>
                    </div>
                  </td>
                  <td>{ad.title}</td>
                  <td>{ad.category?.name_ar || '—'}</td>
                  <td className={styles.priceCell}>
                    {ad.price > 0 ? `${ad.price.toLocaleString('ar-SA')} ر.س` : 'مجاني'}
                  </td>
                  <td>
                    <span className={`${styles.statusBadge} ${styles[ad.status] || ''}`}>
                      {ad.status_label || ad.status}
                    </span>
                  </td>
                  <td className={styles.dateCell}>{timeAgo(ad.created_at)}</td>
                </tr>
              ))}
              {stats.recent_ads.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: 'var(--admin-text-muted)' }}>
                    لا توجد إعلانات حالياً
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
