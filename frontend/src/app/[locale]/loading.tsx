import styles from './loading.module.css';

export default function Loading() {
  return (
    <div className={styles.container}>
      <div className={styles.spinner} aria-label="جاري التحميل" role="status">
        <div className={styles.ring} />
      </div>
    </div>
  );
}
