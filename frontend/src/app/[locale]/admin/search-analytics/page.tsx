'use client';

import { useState, useEffect } from 'react';
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
import { Line, Doughnut } from 'react-chartjs-2';
import {
  fetchTopSearchTerms,
  fetchZeroResultQueries,
  type SearchTermsData,
  type ZeroResultsData,
} from '@/lib/api/admin-analytics';
import styles from './search-analytics.module.css';

ChartJS.register(CategoryScale, LinearScale, BarElement, LineElement, PointElement, ArcElement, Tooltip, Legend, Filler);

const PLATFORM_COLORS: Record<string, string> = {
  web: '#6366f1',
  mobile: '#22c55e',
  api: '#f59e0b',
  unknown: '#94a3b8',
};

const PLATFORM_LABELS: Record<string, string> = {
  web: 'الموقع',
  mobile: 'التطبيق',
  api: 'API',
  unknown: 'غير محدد',
};

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('ar-SA', {
    month: 'short', day: 'numeric',
  });
}

export default function SearchAnalyticsPage() {
  const [searchData, setSearchData] = useState<SearchTermsData | null>(null);
  const [zeroData, setZeroData] = useState<ZeroResultsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetchTopSearchTerms(90),
      fetchZeroResultQueries(90),
    ]).then(([search, zero]) => {
      setSearchData(search);
      setZeroData(zero);
    }).finally(() => setLoading(false));
  }, []);

  // ── Chart configs ──────────────────────────────────────────────────────

  const volumeChartData = searchData ? {
    labels: searchData.daily_volume.map(d => d.label),
    datasets: [{
      label: 'عمليات البحث',
      data: searchData.daily_volume.map(d => d.count),
      fill: true,
      backgroundColor: 'rgba(99, 102, 241, 0.08)',
      borderColor: '#6366f1',
      borderWidth: 2,
      pointRadius: 2,
      tension: 0.4,
    }],
  } : null;

  const platformChartData = searchData ? {
    labels: searchData.platforms.map(p => PLATFORM_LABELS[p.platform] || p.platform),
    datasets: [{
      data: searchData.platforms.map(p => p.count),
      backgroundColor: searchData.platforms.map(p => PLATFORM_COLORS[p.platform] || '#94a3b8'),
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
        backgroundColor: '#ffffff', titleColor: '#0f172a', bodyColor: '#475569',
        borderColor: 'rgba(0,0,0,0.1)', borderWidth: 1, padding: 12, cornerRadius: 8,
        rtl: true, textDirection: 'rtl' as const,
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
    cutout: '65%',
    plugins: {
      legend: { position: 'bottom' as const, rtl: true, labels: { padding: 14, usePointStyle: true, font: { size: 12 }, color: '#94a3b8' } },
      tooltip: { backgroundColor: '#ffffff', titleColor: '#0f172a', bodyColor: '#475569', borderColor: 'rgba(0,0,0,0.1)', borderWidth: 1, padding: 12, cornerRadius: 8, rtl: true, textDirection: 'rtl' as const },
    },
  };

  // ── Render ──────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <div className={styles.loading}>
        <div className={styles.loadingSpinner} />
        <span>جاري تحميل تحليلات البحث...</span>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', marginBottom: '1.5rem' }}>
        🔍 تحليلات البحث
      </h1>

      {/* ── Summary ──────────────────────────────────────────────── */}
      <div className={styles.summaryRow}>
        <div className={styles.summaryCard}>
          <div className={styles.summaryValue}>{(searchData?.total_searches ?? 0).toLocaleString('ar-SA')}</div>
          <div className={styles.summaryLabel}>عمليات بحث (90 يوم)</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryValue}>{searchData?.terms?.length ?? 0}</div>
          <div className={styles.summaryLabel}>كلمات بحث فريدة</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryValue} style={{ color: '#ef4444' }}>{zeroData?.total_zero ?? 0}</div>
          <div className={styles.summaryLabel}>بحث بدون نتائج</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryValue}>{searchData?.platforms?.length ?? 0}</div>
          <div className={styles.summaryLabel}>منصات</div>
        </div>
      </div>

      {/* ── Search Volume Chart ──────────────────────────────────── */}
      {volumeChartData && (
        <div className={`${styles.card} ${styles.fullWidth}`} style={{ marginBottom: '1.25rem' }}>
          <div className={styles.cardTitle}>📈 حجم البحث اليومي (آخر 30 يوم)</div>
          <div className={styles.chartWrapper}>
            <Line data={volumeChartData} options={lineOptions} />
          </div>
        </div>
      )}

      {/* ── Two-column: Terms + Zero Results ─────────────────────── */}
      <div className={styles.twoCol}>
        {/* Top Search Terms */}
        <div className={styles.card}>
          <div className={styles.cardTitle}>🔥 أكثر الكلمات بحثاً</div>
          <div className={styles.scrollable}>
            <table className={styles.termsTable}>
              <thead>
                <tr>
                  <th>#</th>
                  <th>الكلمة</th>
                  <th>عدد البحث</th>
                  <th>متوسط النتائج</th>
                  <th>آخر بحث</th>
                </tr>
              </thead>
              <tbody>
                {(searchData?.terms ?? []).map((term, i) => (
                  <tr key={term.query}>
                    <td style={{ color: '#94a3b8', fontWeight: 600 }}>{i + 1}</td>
                    <td className={styles.queryText}>{term.query}</td>
                    <td><span className={styles.countBadge}>{term.search_count}</span></td>
                    <td className={styles.avgResults}>{term.avg_results}</td>
                    <td className={styles.dateCell}>{formatDate(term.last_searched)}</td>
                  </tr>
                ))}
                {(!searchData?.terms || searchData.terms.length === 0) && (
                  <tr><td colSpan={5} style={{ textAlign: 'center', color: '#94a3b8', padding: '2rem' }}>لا توجد بيانات</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Zero-Result Queries */}
        <div className={styles.card}>
          <div className={styles.cardTitle}>⚠️ بحث بدون نتائج (فجوات المحتوى)</div>
          <div className={styles.scrollable}>
            <table className={styles.termsTable}>
              <thead>
                <tr>
                  <th>#</th>
                  <th>الكلمة</th>
                  <th>عدد البحث</th>
                  <th>آخر بحث</th>
                </tr>
              </thead>
              <tbody>
                {(zeroData?.terms ?? []).map((term, i) => (
                  <tr key={term.query}>
                    <td style={{ color: '#94a3b8', fontWeight: 600 }}>{i + 1}</td>
                    <td className={styles.queryText}>{term.query}</td>
                    <td><span className={styles.zeroCountBadge}>{term.search_count}</span></td>
                    <td className={styles.dateCell}>{formatDate(term.last_searched)}</td>
                  </tr>
                ))}
                {(!zeroData?.terms || zeroData.terms.length === 0) && (
                  <tr><td colSpan={4} style={{ textAlign: 'center', color: '#94a3b8', padding: '2rem' }}>لا توجد بيانات 🎉</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* ── Platform Breakdown ──────────────────────────────────── */}
      <div className={styles.twoCol}>
        {platformChartData && (
          <div className={styles.card}>
            <div className={styles.cardTitle}>📱 البحث حسب المنصة</div>
            <div className={styles.chartWrapper}>
              <Doughnut data={platformChartData} options={doughnutOptions} />
            </div>
          </div>
        )}

        <div className={styles.card}>
          <div className={styles.cardTitle}>📊 توزيع المنصات</div>
          <div className={styles.platformList} style={{ padding: '1rem 0' }}>
            {(searchData?.platforms ?? []).map(p => (
              <div key={p.platform} className={styles.platformChip}>
                <span className={styles.platformDot} style={{ background: PLATFORM_COLORS[p.platform] || '#94a3b8' }} />
                <span className={styles.platformLabel}>{PLATFORM_LABELS[p.platform] || p.platform}</span>
                <span className={styles.platformCount}>{p.count.toLocaleString('ar-SA')}</span>
              </div>
            ))}
            {(!searchData?.platforms || searchData.platforms.length === 0) && (
              <p style={{ color: '#94a3b8' }}>لا توجد بيانات</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
