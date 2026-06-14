import Link from 'next/link';
import styles from './Footer.module.css';

export default function Footer() {
  return (
    <footer className={styles.footer} dir="rtl">
      <div className={styles.inner}>
        {/* Brand */}
        <div className={styles.brand}>
          <Link href="/ar" className={styles.logo}>
            <span className={styles.logoIcon}>⚡</span>
            <span className={styles.logoText}>
              برق <strong>واضح</strong>
            </span>
          </Link>
          <p className={styles.tagline}>
            منصة الإعلانات المبوبة الأولى في المملكة العربية السعودية
          </p>
        </div>

        {/* Links */}
        <div className={styles.links}>
          <div className={styles.col}>
            <h4 className={styles.colTitle}>المنصة</h4>
            <Link href="/ar/search" className={styles.link}>
              البحث المتقدم
            </Link>
            <Link href="/ar/post-ad" className={styles.link}>
              أضف إعلانك
            </Link>
            <Link href="/ar/fees" className={styles.link}>
              الرسوم والأسعار
            </Link>
            <Link href="/ar/how-we-buy" className={styles.link}>
              كيف نشتري
            </Link>
            <Link href="/ar/how-we-sell" className={styles.link}>
              كيف نبيع
            </Link>
          </div>
          <div className={styles.col}>
            <h4 className={styles.colTitle}>الدعم والمعلومات</h4>
            <Link href="/ar/about" className={styles.link}>
              من نحن
            </Link>
            <Link href="/ar/contact" className={styles.link}>
              تواصل معنا
            </Link>
            <Link href="/ar/terms" className={styles.link}>
              الشروط والأحكام
            </Link>
            <Link href="/ar/privacy" className={styles.link}>
              سياسة الخصوصية
            </Link>
          </div>
        </div>
      </div>

      <div className={styles.bottom}>
        <p className={styles.copy}>© {new Date().getFullYear()} برق واضح. جميع الحقوق محفوظة.</p>
        <div className={styles.badges}>
          <span className={styles.badge}>🇸🇦 مصنوع في السعودية</span>
        </div>
      </div>
    </footer>
  );
}
