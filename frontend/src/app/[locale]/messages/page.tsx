'use client';

import { MessageSquare } from 'lucide-react';
import styles from './page.module.css';

export default function MessagesPage() {
  return (
    <div className={styles.emptyPane}>
      <div className={styles.emptyCard}>
        <MessageSquare size={64} strokeWidth={1} className={styles.emptyIcon} />
        <h2>اختر محادثة لعرضها</h2>
        <p>اختر محادثة من القائمة، أو ابدأ محادثة جديدة من صفحة أي إعلان.</p>
      </div>
    </div>
  );
}
