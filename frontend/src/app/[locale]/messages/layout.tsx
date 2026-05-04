'use client';

import Link from 'next/link';
import { useParams, usePathname } from 'next/navigation';
import { MessageSquare } from 'lucide-react';
import Header from '@/components/layout/Header/Header';
import ConversationList from '@/components/messages/ConversationList';
import { useAuthStore } from '@/store/auth.store';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import styles from './layout.module.css';

export default function MessagesLayout({ children }: { children: React.ReactNode }) {
  const { locale }   = useParams<{ locale: string }>();
  const pathname     = usePathname();
  const { isAuthenticated, _hasHydrated } = useAuthStore();
  useRequireAuth();

  // Active conversation = anything matching /messages/<id> (not just /messages)
  const match = pathname?.match(/\/messages\/([^/]+)$/);
  const activeId = match?.[1] ?? null;
  const isConvActive = !!activeId;

  if (!_hasHydrated) return null;

  if (!isAuthenticated) {
    return (
      <>
        <Header />
        <main className={styles.unauthShell} dir="rtl">
          <div className={styles.unauthCard}>
            <div className={styles.unauthIcon}><MessageSquare size={56} strokeWidth={1.2} /></div>
            <h2>سجّل الدخول للوصول إلى رسائلك</h2>
            <p>راسل البائعين، اطلع على ردودهم، وأكمل صفقاتك بأمان.</p>
            <Link href={`/${locale}/login`} className={styles.unauthBtn}>تسجيل الدخول</Link>
          </div>
        </main>
      </>
    );
  }

  return (
    <>
      <Header />
      <main className={styles.shell} dir="rtl">
        <aside
          className={`${styles.sidebar} ${isConvActive ? styles.sidebarHiddenMobile : ''}`}
          aria-label="قائمة المحادثات"
        >
          <ConversationList activeConversationId={activeId} />
        </aside>

        <section
          className={`${styles.main} ${!isConvActive ? styles.mainHiddenMobile : ''}`}
          aria-label="المحادثة"
        >
          {children}
        </section>
      </main>
    </>
  );
}
