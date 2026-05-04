// Categories may store the icon as either an emoji string ("🚗") or a URL
// to an uploaded image. Render the right element for each so URLs don't
// leak into the DOM as raw text.

type Props = {
  icon: string | null | undefined;
  size: number;
  fallback?: string;
  alt?: string;
};

export function CategoryIcon({ icon, size, fallback = '📦', alt = '' }: Props) {
  if (!icon) return <span style={{ fontSize: size, lineHeight: 1 }}>{fallback}</span>;
  if (icon.startsWith('http') || icon.startsWith('/')) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={icon}
        alt={alt}
        width={size}
        height={size}
        style={{ objectFit: 'contain', borderRadius: 6 }}
      />
    );
  }
  return <span style={{ fontSize: size, lineHeight: 1 }}>{icon}</span>;
}
