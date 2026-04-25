import styles from './Card.module.css';

export type CardProps = React.HTMLAttributes<HTMLDivElement> & {
  hover?: boolean;
  padding?: 'sm' | 'md' | 'lg' | 'none';
};

export default function Card({ hover = false, padding = 'md', className = '', children, ...props }: CardProps) {
  return (
    <div
      className={[styles.card, hover ? styles.hover : '', styles[`padding-${padding}`], className].filter(Boolean).join(' ')}
      {...props}
    >
      {children}
    </div>
  );
}
