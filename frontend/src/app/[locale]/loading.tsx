import styles from './loading.module.css';

// Brand-aligned navigation loader. "برق" (Barq) means lightning, so the loader
// is a glowing bolt that "charges" with an energy sweep over a pulsing halo.
const BOLT =
  'M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z';

export default function Loading() {
  return (
    <div className={styles.container} role="status" aria-label="جاري التحميل">
      <div className={styles.stage}>
        <span className={styles.halo} aria-hidden="true" />
        <svg className={styles.svg} viewBox="0 0 24 24" aria-hidden="true">
          <defs>
            <linearGradient id="boltFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#FFCA28" />
              <stop offset="100%" stopColor="#2A5298" />
            </linearGradient>
            <linearGradient id="boltSweep" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="rgba(255,243,196,0)" />
              <stop offset="42%" stopColor="rgba(255,243,196,0)" />
              <stop offset="50%" stopColor="rgba(255,247,214,0.95)" />
              <stop offset="58%" stopColor="rgba(255,243,196,0)" />
              <stop offset="100%" stopColor="rgba(255,243,196,0)" />
            </linearGradient>
            <clipPath id="boltClip">
              <path d={BOLT} />
            </clipPath>
          </defs>

          {/* Base bolt — always visible */}
          <path d={BOLT} fill="url(#boltFill)" className={styles.fill} />

          {/* Energy sweep, clipped to the bolt silhouette */}
          <g clipPath="url(#boltClip)">
            <rect
              className={styles.sweep}
              x="0"
              y="-12"
              width="24"
              height="48"
              fill="url(#boltSweep)"
            />
          </g>

          {/* Crisp gold outline */}
          <path d={BOLT} className={styles.stroke} fill="none" />
        </svg>
      </div>

      <span className={styles.label}>برق واضح</span>
    </div>
  );
}
