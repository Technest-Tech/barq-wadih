import type { Metadata } from 'next';
import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { fetchStaticPage } from '@/lib/api/server-fetchers';
import s from '../static-page.module.css';

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const page = await fetchStaticPage('about');
  const isAr = locale === 'ar';
  return {
    title: isAr ? (page?.title_ar ?? 'من نحن') : (page?.title_en ?? 'About Us'),
    description: isAr ? page?.meta_description_ar : page?.meta_description_en,
  };
}

export default async function AboutPage({ params }: Props) {
  const { locale } = await params;
  const isAr = locale === 'ar';
  const page = await fetchStaticPage('about');

  const title = isAr ? (page?.title_ar ?? 'من نحن') : (page?.title_en ?? 'About Us');
  const content = isAr ? (page?.content_ar ?? '') : (page?.content_en ?? '');

  return (
    <div className={s.wrapper} dir={isAr ? 'rtl' : 'ltr'}>
      <Header />

      <div className={s.hero}>
        <h1 className={s.heroTitle}>{title}</h1>
        <div className={s.heroBreadcrumb}>
          <Link href={`/${locale}`}>{isAr ? 'الرئيسية' : 'Home'}</Link>
          <span>›</span>
          <span>{title}</span>
        </div>
      </div>

      <div className={s.container}>
        <div className={s.card}>
          {content ? (
            <>
              <div className={s.content} dangerouslySetInnerHTML={{ __html: content }} />
              {page?.updated_at && (
                <p className={s.updatedAt}>
                  {isAr ? 'آخر تحديث:' : 'Last updated:'}{' '}
                  {new Date(page.updated_at).toLocaleDateString(isAr ? 'ar-SA' : 'en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </p>
              )}
            </>
          ) : (
            <div className={s.notFound}>
              <h2>{isAr ? 'المحتوى غير متاح حالياً' : 'Content not available'}</h2>
              <p>{isAr ? 'يُرجى المحاولة لاحقاً.' : 'Please check back later.'}</p>
            </div>
          )}
        </div>
      </div>

      <Footer />
    </div>
  );
}
