'use client';

import { useRef, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { usePostAdWizard, type WizardImage } from '@/store/postAdWizard.store';
import { WizardFooter } from '../WizardFooter';

const MAX_IMAGES = 10;

/**
 * Step 7 — Image picker with reorder. The first non-removed image is marked
 * primary. Files are kept off the persisted draft on purpose; reload starts
 * from existing-image references (edit mode) only.
 */
export function ImagesStep() {
  const images = usePostAdWizard(s => s.images);
  const addImages = usePostAdWizard(s => s.addImages);
  const removeImage = usePostAdWizard(s => s.removeImage);
  const reorderImages = usePostAdWizard(s => s.reorderImages);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const fileBlobsRef = useRef<Map<string, File>>(new Map());
  const [dragId, setDragId] = useState<string | null>(null);

  // Expose the file blobs to the submit step via a window-scoped registry.
  // Preserves blobs across renders without persisting to localStorage.
  if (typeof window !== 'undefined') {
    (window as unknown as { __barqAdImageBlobs?: Map<string, File> }).__barqAdImageBlobs = fileBlobsRef.current;
  }

  const visible = images.filter(i => !i.removed);
  const total = visible.length;

  const handleAdd = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []).slice(0, MAX_IMAGES - total);
    const newOnes: WizardImage[] = [];
    files.forEach(f => {
      const id = `new-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      fileBlobsRef.current.set(id, f);
      const reader = new FileReader();
      reader.onload = (ev) => {
        // Patch in the data URL once the FileReader resolves; the wizard
        // reads previewUrl for display, not the blob.
        const url = ev.target?.result as string;
        addImages([{ id, previewUrl: url }]);
      };
      reader.readAsDataURL(f);
    });
    if (e.target) e.target.value = '';
    return newOnes;
  };

  const onDragStart = (id: string) => setDragId(id);
  const onDragOver = (e: React.DragEvent) => e.preventDefault();
  const onDrop = (targetId: string) => {
    if (!dragId || dragId === targetId) return;
    const fromIdx = images.findIndex(i => i.id === dragId);
    const toIdx = images.findIndex(i => i.id === targetId);
    if (fromIdx >= 0 && toIdx >= 0) reorderImages(fromIdx, toIdx);
    setDragId(null);
  };

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📸</span>
        <div>
          <div className={styles.stepTitle}>صور الإعلان</div>
          <div className={styles.stepSub}>من 1 إلى 10 صور — السحب لإعادة الترتيب</div>
        </div>
      </header>

      <p className={styles.imageHint}>
        الصورة الأولى ستظهر كصورة رئيسية. الصيغ المدعومة: JPG، PNG، WebP — الحجم الأقصى 5 ميجا لكل صورة.
      </p>

      <div className={styles.imageGrid}>
        {visible.map((img, idx) => (
          <div
            key={img.id}
            className={`${styles.imageThumb} ${dragId === img.id ? styles.dragging : ''}`}
            draggable
            onDragStart={() => onDragStart(img.id)}
            onDragOver={onDragOver}
            onDrop={() => onDrop(img.id)}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={img.previewUrl} alt={`صورة ${idx + 1}`} />
            {idx === 0 && <span className={styles.primaryBadge}>رئيسية</span>}
            <button type="button" className={styles.removeImg} onClick={() => removeImage(img.id)}>✕</button>
          </div>
        ))}
        {total < MAX_IMAGES && (
          <button
            type="button"
            className={styles.addImage}
            onClick={() => fileInputRef.current?.click()}
          >
            <span>+</span>
            <span>إضافة صورة</span>
          </button>
        )}
      </div>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        multiple
        hidden
        onChange={handleAdd}
      />

      <p className={pm.pmHelp} style={{ marginTop: 10 }}>
        {total === 0 ? 'أضف صورة واحدة على الأقل للمتابعة' : `${total} من ${MAX_IMAGES}`}
      </p>

      <WizardFooter />
    </div>
  );
}
