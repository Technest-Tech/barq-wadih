import styles from './Avatar.module.css';

export type AvatarProps = {
  src?: string | null;
  name?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
};

function getInitials(name: string): string {
  return name
    .split(' ')
    .slice(0, 2)
    .map((n) => n.charAt(0).toUpperCase())
    .join('');
}

function getColorIndex(name: string): number {
  return name.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0) % 6;
}

const colors = ['#1B5E20', '#1565C0', '#6A1B9A', '#BF360C', '#00695C', '#558B2F'];

export default function Avatar({ src, name = '', size = 'md', className = '' }: AvatarProps) {
  const initials = getInitials(name);
  const bgColor = colors[getColorIndex(name)];

  if (src) {
    return (
      <img
        src={src}
        alt={name || 'Avatar'}
        className={[styles.avatar, styles[size], className].filter(Boolean).join(' ')}
      />
    );
  }

  return (
    <div
      className={[styles.avatar, styles.fallback, styles[size], className].filter(Boolean).join(' ')}
      style={{ backgroundColor: bgColor }}
      aria-label={name}
      role="img"
    >
      {initials || '؟'}
    </div>
  );
}
