'use client';

import { useState, useEffect, useCallback } from 'react';
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
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  fetchRevenueAnalytics,
  fetchAdsByCity,
  type RevenueData,
  type CityDistribution,
} from '@/lib/api/admin-analytics';
import { fetchCommissionSummary, type CommissionSummary } from '@/lib/api/admin-commissions';
import styles from './analytics.module.css';

ChartJS.register(CategoryScale, LinearScale, BarElement, LineElement, PointElement, ArcElement, Tooltip, Legend, Filler);

const PERIODS = [
  { key: '7d', label: '7 أيام' },
  { key: '30d', label: '30 يوم' },
  { key: '90d', label: '90 يوم' },
  { key: '1y', label: 'سنة' },
];

const CITY_COLORS = [
  '#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899',
  '#f43f5e', '#ef4444', '#f97316', '#f59e0b', '#eab308',
  '#84cc16', '#22c55e', '#10b981', '#14b8a6', '#06b6d4',
  '#0ea5e9', '#3b82f6', '#2563eb', '#4f46e5', '#7c3aed',
];

function formatCurrency(n: number): string {
  return `${n.toLocaleString('ar-SA', { maximumFractionDigits: 0 })} ر.س`;
}

export default function AdminAnalyticsPage() {
  const [period, setPeriod] = useState('30d');
  const [revenue, setRevenue] = useState<RevenueData | null>(null);
  const [cities, setCities] = useState<CityDistribution[]>([]);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [loading, setLoading] = useState(true);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [rev, cityData, sum] = await Promise.all([
        fetchRevenueAnalytics(period),
        fetchAdsByCity(),
        fetchCommissionSummary(),
      ]);
      setRevenue(rev);
      setCities(cityData);
      setSummary(sum);
    } catch {
      // silent
    } finally {
      setLoading(false);
    }
  }, [period]);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Chart configs ──────────────────────────────────────────────────────

  const revenueChartData = revenue ? {
    labels: revenue.series.map(s => s.label),
    datasets: [{
      label: 'الإيرادات (ر.س)',
      data: revenue.series.map(s => s.revenue),
      fill: true,
      backgroundColor: 'rgba(34, 197, 94, 0.08)',
      borderColor: '#22c55e',
      borderWidth: 2,
      pointBackgroundColor: '#22c55e',
      pointBorderColor: '#ffffff',
      pointBorderWidth: 2,
      pointRadius: 3,
      tension: 0.4,
    }],
  } : null;

  const statusChartData = summary ? {
    labels: summary.by_status.map(s => s.label),
    datasets: [{
      data: summary.by_status.map(s => s.count),
      backgroundColor: ['#64748b', '#f59e0b', '#22c55e'],
      borderWidth: 0,
      hoverOffset: 8,
    }],
  } : null;

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
      x: { grid: { display: false }, ticks: { font: { size: 10 }, color: '#94a3b8' } },
      y: { grid: { color: 'rgba(255,255,255,0.04)' }, ticks: { font: { size: 10 }, color: '#94a3b8' }, beginAtZero: true },
    },
  };

  const doughnutOptions = {
    responsive: true,
    maintainAspectRatio: false,
    cutout: '70%',
    plugins: {
      legend: { position: 'bottom' as const, rtl: true, labels: { padding: 16, usePointStyle: true, font: { size: 12 }, color: '#94a3b8' } },
      tooltip: { backgroundColor: '#ffffff', titleColor: '#0f172a', bodyColor: '#475569', borderColor: 'rgba(0,0,0,0.1)', borderWidth: 1, padding: 12, cornerRadius: 8, rtl: true, textDirection: 'rtl' as const },
    },
  };

  const maxCityCount = cities.length > 0 ? cities[0].ad_count : 1;

  // ── Render ──────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <div className={styles.loading}>
        <div className={styles.loadingSpinner} />
        <span>جاري تحميل التحليلات...</span>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', marginBottom: '1.5rem' }}>
        📈 التحليلات المالية
      </h1>

      {/* ── Period Tabs ──────────────────────────────────────────── */}
      <div className={styles.periodTabs}>
        {PERIODS.map(p => (
          <button
            key={p.key}
            className={`${styles.periodTab} ${period === p.key ? styles.periodTabActive : ''}`}
            onClick={() => setPeriod(p.key)}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* ── Metrics Row ─────────────────────────────────────────── */}
      {revenue && summary && (
        <div className={styles.metricsRow}>
          <div className={styles.metricCard}>
            <div className={styles.metricValue}>{formatCurrency(revenue.total_revenue)}</div>
            <div className={styles.metricLabel}>إيرادات الفترة</div>
          </div>
          <div className={styles.metricCard}>
            <div className={styles.metricValue}>{revenue.total_transactions}</div>
            <div className={styles.metricLabel}>عدد المعاملات</div>
          </div>
          <div className={styles.metricCard}>
            <div className={styles.metricValue}>{formatCurrency(summary.avg_commission)}</div>
            <div className={styles.metricLabel}>متوسط العمولة</div>
          </div>
          <div className={styles.metricCard}>
            <div className={styles.metricValue}>{formatCurrency(summary.max_commission)}</div>
            <div className={styles.metricLabel}>أعلى عمولة</div>
          </div>
        </div>
      )}

      {/* ── Charts ──────────────────────────────────────────────── */}
      <div className={styles.chartsGrid}>
        {/* Revenue Chart */}
        {revenueChartData && (
          <div className={`${styles.chartCard} ${styles.fullWidth}`}>
            <div className={styles.chartTitle}>💵 الإيرادات خلال الفترة ({revenue?.grouping === 'daily' ? 'يومياً' : revenue?.grouping === 'weekly' ? 'أسبوعياً' : 'شهرياً'})</div>
            <div className={styles.chartWrapper}>
              <Line data={revenueChartData} options={lineOptions} />
            </div>
          </div>
        )}

        {/* Commission Status */}
        {statusChartData && (
          <div className={styles.chartCard}>
            <div className={styles.chartTitle}>📊 العمولات حسب الحالة</div>
            <div className={styles.chartWrapper}>
              <Doughnut data={statusChartData} options={doughnutOptions} />
            </div>
          </div>
        )}

        {/* Ad Distribution by City */}
        <div className={styles.chartCard}>
          <div className={styles.chartTitle}>🏙️ توزيع الإعلانات حسب المدينة (أعلى 20)</div>
          <div className={styles.cityList}>
            {cities.map((city, i) => (
              <div key={city.city_id} className={styles.cityRow}>
                <span className={styles.cityRank}>{i + 1}</span>
                <span className={styles.cityName}>{city.city_name}</span>
                <div className={styles.cityBarWrap}>
                  <div
                    className={styles.cityBar}
                    style={{
                      width: `${(city.ad_count / maxCityCount) * 100}%`,
                      background: CITY_COLORS[i % CITY_COLORS.length],
                    }}
                  />
                </div>
                <span className={styles.cityCount}>{city.ad_count}</span>
                <span className={styles.regionTag}>{city.region_name}</span>
              </div>
            ))}
            {cities.length === 0 && (
              <p style={{ color: '#94a3b8', textAlign: 'center', padding: '2rem' }}>لا توجد بيانات</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
