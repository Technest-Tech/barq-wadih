import styles from './Badge.module.css';

type BadgeVariant = 'active' | 'sold' | 'expired' | 'verified' | 'pending' | 'rejected' | 'info' | 'default';

export type BadgeProps = {
  variant?: BadgeVariant;
  children: React.ReactNode;
  className?: string;
};

export default function Badge({ variant = 'default', children, className = '' }: BadgeProps) {
  return (
    <span className={[styles.badge, styles[variant], className].filter(Boolean).join(' ')}>
      {children}
    </span>
  );
}
