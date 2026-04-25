import type { Metadata } from 'next';
import styles from './layout.module.css';

export const metadata: Metadata = {
  title: 'تسجيل الدخول | برق واضح',
  description: 'سجّل دخولك أو أنشئ حسابك في برق واضح — منصة الإعلانات المبوبة الأولى في السعودية',
};

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className={styles.wrapper}>

      {/* ── Brand mural (desktop only) ── */}
      <div className={styles.mural}>
        <div className={styles.muralContent}>
          <div className={styles.logoMark}>⚡</div>
          <div>
            <h1 className={styles.brandName}>
              برق <span className={styles.brandNameAccent}>واضح</span>
            </h1>
          </div>
          <p className={styles.brandTagline}>
            منصة الإعلانات المبوبة الأولى في المملكة العربية السعودية
          </p>
          <div className={styles.stats}>
            <div className={styles.stat}>
              <span className={styles.statNum}>+500K</span>
              <span className={styles.statLabel}>إعلان</span>
            </div>
            <div className={styles.stat}>
              <span className={styles.statNum}>+200K</span>
              <span className={styles.statLabel}>مستخدم</span>
            </div>
            <div className={styles.stat}>
              <span className={styles.statNum}>13</span>
              <span className={styles.statLabel}>منطقة</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Form panel ── */}
      <div className={styles.formPanel}>
        {/* Mobile logo */}
        <div className={styles.mobileLogo}>
          <div className={styles.mobileLogoMark}>⚡</div>
          <span className={styles.mobileLogoName}>برق واضح</span>
        </div>
        {children}
      </div>

    </div>
  );
}
