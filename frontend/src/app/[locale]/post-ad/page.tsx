'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { fetchCategoryFields, createAd, updateAd, fetchAd, fetchCommissionPreview, type CategoryField, type CommissionPreview } from '@/lib/api/ads';
import { fetchRegions, fetchCities, type Region, type City } from '@/lib/api/regions';
import { fetchCategories, type Category, type CategoryChild } from '@/lib/api/categories';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

// ── Step config ───────────────────────────────────────────────────────────────

const STEPS = [
  { id: 1, label: 'التصنيف', icon: '📂' },
  { id: 2, label: 'التفاصيل', icon: '📝' },
  { id: 3, label: 'الصور', icon: '📸' },
  { id: 4, label: 'الموقع', icon: '📍' },
  { id: 5, label: 'المراجعة', icon: '✅' },
];

// ── Main page ─────────────────────────────────────────────────────────────────

export default function PostAdPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { isAuthenticated } = useAuthStore();
  const editId = searchParams.get('edit');
  const isEditMode = !!editId;

  const [step, setStep] = useState(1);
  const [submitting, setSubmitting] = useState(false);
  const [loadingEdit, setLoadingEdit] = useState(isEditMode);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Step 1 — Category
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedParent, setSelectedParent] = useState<Category | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<CategoryChild | null>(null);

  // Step 2 — Details
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState('');
  const [isNegotiable, setIsNegotiable] = useState(false);
  const [isFree, setIsFree] = useState(false);
  const [phone, setPhone] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [fields, setFields] = useState<CategoryField[]>([]);
  const [fieldValues, setFieldValues] = useState<Record<string, string>>({});

  // Step 3 — Images
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [imagePreviews, setImagePreviews] = useState<string[]>([]);
  const [existingImages, setExistingImages] = useState<{ id: number; url: string }[]>([]);
  const [removeImageIds, setRemoveImageIds] = useState<number[]>([]);

  // Step 4 — Location
  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const [selectedCity, setSelectedCity] = useState<City | null>(null);
  const [pledgeAccepted, setPledgeAccepted] = useState(false);

  // Step 5 — Commission
  const [commission, setCommission] = useState<CommissionPreview | null>(null);

  // ── Auth guard ──────────────────────────────────────────────────────────────

  useEffect(() => {
    if (!isAuthenticated) {
      router.replace('/ar/login');
    }
  }, [isAuthenticated, router]);

  // Load categories and regions on mount
  useEffect(() => {
    fetchCategories().then(setCategories).catch(console.error);
    fetchRegions().then(setRegions).catch(console.error);
  }, []);

  // ── Edit mode: Load existing ad ─────────────────────────────────────────────

  useEffect(() => {
    if (!editId) return;
    setLoadingEdit(true);

    fetchAd(Number(editId))
      .then(async (ad) => {
        // Pre-populate fields
        setTitle(ad.title);
        setDescription(ad.description);
        setPrice(ad.price ?? '');
        setIsNegotiable(ad.is_negotiable);
        setIsFree(ad.is_free);
        setPhone(ad.contact_phone);
        setWhatsapp(ad.contact_whatsapp ?? '');
        setPledgeAccepted(true);

        // Pre-populate existing images
        setExistingImages(ad.images.map(img => ({ id: img.id, url: img.image_url })));

        // Pre-populate field values
        const fv: Record<string, string> = {};
        ad.field_values.forEach(v => { fv[v.field_key] = String(v.value ?? ''); });
        setFieldValues(fv);

        // Find and select category
        const cats = await fetchCategories();
        setCategories(cats);
        for (const parent of cats) {
          if (parent.id === ad.category?.id) {
            setSelectedParent(parent);
            setSelectedCategory(parent);
            break;
          }
          const child = parent.children?.find(c => c.id === ad.category?.id);
          if (child) {
            setSelectedParent(parent);
            setSelectedCategory(child);
            break;
          }
        }

        // Find and select region/city
        const regs = await fetchRegions();
        setRegions(regs);
        const reg = regs.find(r => r.id === ad.region?.id) ?? null;
        setSelectedRegion(reg);
        if (reg) {
          const cits = await fetchCities(reg.slug);
          setCities(cits);
          setSelectedCity(cits.find(c => c.id === ad.city?.id) ?? null);
        }

        // Skip to step 2 (category already selected)
        setStep(2);
      })
      .catch(console.error)
      .finally(() => setLoadingEdit(false));
  }, [editId]);

  // Load subcategory fields when category selected
  useEffect(() => {
    if (!selectedCategory) { setFields([]); return; }
    fetchCategoryFields(selectedCategory.id).then(setFields).catch(console.error);
  }, [selectedCategory]);

  // Load cities when region selected
  useEffect(() => {
    if (!selectedRegion) { setCities([]); return; }
    fetchCities(selectedRegion.slug).then(setCities).catch(console.error);
  }, [selectedRegion]);

  // Fetch commission preview when entering step 5
  useEffect(() => {
    if (step !== 5) return;
    const p = isFree ? 0 : Number(price) || 0;
    fetchCommissionPreview(p, isFree).then(setCommission).catch(console.error);
  }, [step, price, isFree]);

  // ── Image handlers ──────────────────────────────────────────────────────────

  const handleImageAdd = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []);
    const totalCurrent = existingImages.length - removeImageIds.length + imageFiles.length;
    const remaining = 10 - totalCurrent;
    const toAdd = files.slice(0, remaining);
    setImageFiles(prev => [...prev, ...toAdd]);
    toAdd.forEach(f => {
      const reader = new FileReader();
      reader.onload = (ev) => setImagePreviews(prev => [...prev, ev.target?.result as string]);
      reader.readAsDataURL(f);
    });
  }, [imageFiles.length, existingImages.length, removeImageIds.length]);

  const removeNewImage = (index: number) => {
    setImageFiles(prev => prev.filter((_, i) => i !== index));
    setImagePreviews(prev => prev.filter((_, i) => i !== index));
  };

  const removeExistingImage = (imgId: number) => {
    setRemoveImageIds(prev => [...prev, imgId]);
  };

  // ── Submit ──────────────────────────────────────────────────────────────────

  const handleSubmit = async () => {
    if (!selectedCategory || !selectedCity) return;
    setSubmitting(true);
    setErrors({});
    try {
      const fd = new FormData();

      if (!isEditMode) {
        // Creating — send all required fields
        fd.append('category_id', String(selectedCategory.id));
        fd.append('pledge_accepted', '1');
      }

      fd.append('city_id', String(selectedCity.id));
      fd.append('title', title);
      fd.append('description', description);
      fd.append('price', isFree ? '0' : price);
      fd.append('is_negotiable', isNegotiable ? '1' : '0');
      fd.append('is_free', isFree ? '1' : '0');
      fd.append('contact_phone', phone);
      if (whatsapp) fd.append('contact_whatsapp', whatsapp);
      imageFiles.forEach(f => fd.append('images[]', f));
      Object.entries(fieldValues).forEach(([k, v]) => fd.append(`fields[${k}]`, v));

      if (isEditMode) {
        // Send remove_image_ids for edit
        removeImageIds.forEach(id => fd.append('remove_image_ids[]', String(id)));
        const ad = await updateAd(Number(editId), fd);
        router.push(`/ar/ads/${ad.id}`);
      } else {
        const ad = await createAd(fd);
        router.push(`/ar/ads/${ad.id}`);
      }
    } catch (err: unknown) {
      const e = err as { errors?: Record<string, string[]>; message?: string };
      if (e.errors) {
        const flat: Record<string, string> = {};
        Object.entries(e.errors).forEach(([k, v]) => { flat[k] = v[0]; });
        setErrors(flat);
        // Find which step has the first error and go there
        if (flat.category_id) setStep(1);
        else if (flat.title || flat.description || flat.price || flat.contact_phone) setStep(2);
        else if (flat.images) setStep(3);
        else if (flat.city_id) setStep(4);
      }
    } finally {
      setSubmitting(false);
    }
  };

  // ── Render ──────────────────────────────────────────────────────────────────

  if (!isAuthenticated) return null; // Redirecting...

  if (loadingEdit) {
    return (
      <>
        <Header />
        <main className={styles.main}>
          <div className={styles.container}>
            <div className={styles.loadingWrap}>
              <div className={styles.spinner} />
              <p>جارٍ تحميل بيانات الإعلان...</p>
            </div>
          </div>
        </main>
        <Footer />
      </>
    );
  }

  // All returned categories are top-level with children array
  const topLevel = categories;
  const children = selectedParent?.children ?? [];
  const totalImages = existingImages.filter(img => !removeImageIds.includes(img.id)).length + imageFiles.length;

  return (
    <>
      <Header />
      <main className={styles.main}>
        <div className={styles.container}>
          <h1 className={styles.pageTitle}>{isEditMode ? 'تعديل الإعلان' : 'نشر إعلان جديد'}</h1>

          {/* Step indicator */}
          <div className={styles.stepper}>
            {STEPS.map((s, i) => (
              <div key={s.id} className={styles.stepperItem}>
                <button
                  className={`${styles.stepCircle} ${step === s.id ? styles.active : ''} ${step > s.id ? styles.done : ''}`}
                  onClick={() => step > s.id && setStep(s.id)}
                  disabled={step <= s.id}
                >
                  {step > s.id ? '✓' : s.icon}
                </button>
                <span className={styles.stepLabel}>{s.label}</span>
                {i < STEPS.length - 1 && <div className={`${styles.stepConnector} ${step > s.id ? styles.connectorDone : ''}`} />}
              </div>
            ))}
          </div>

          <div className={styles.card}>
            {/* ── Step 1: Category ── */}
            {step === 1 && (
              <div className={styles.stepContent}>
                <h2 className={styles.stepTitle}>اختر التصنيف</h2>
                {isEditMode && (
                  <p className={styles.hint}>⚠️ لا يمكن تغيير التصنيف عند التعديل</p>
                )}
                <div className={styles.catGrid}>
                  {topLevel.map(cat => (
                    <button
                      key={cat.id}
                      className={`${styles.catBtn} ${selectedParent?.id === cat.id ? styles.catBtnActive : ''}`}
                      onClick={() => { if (!isEditMode) { setSelectedParent(cat); setSelectedCategory(null); } }}
                      disabled={isEditMode}
                    >
                      <span className={styles.catIcon}>{cat.icon ?? '📂'}</span>
                      <span>{cat.name_ar}</span>
                    </button>
                  ))}
                </div>

                {selectedParent && (
                  <>
                    <h3 className={styles.subTitle}>التصنيف الفرعي</h3>
                    <div className={styles.subGrid}>
                      {children.length > 0 ? children.map(sub => (
                        <button
                          key={sub.id}
                          className={`${styles.subBtn} ${selectedCategory?.id === sub.id ? styles.subBtnActive : ''}`}
                          onClick={() => { if (!isEditMode) setSelectedCategory(sub); }}
                          disabled={isEditMode}
                        >
                          {sub.name_ar}
                        </button>
                      )) : (
                        <button
                          className={`${styles.subBtn} ${selectedCategory?.id === selectedParent.id ? styles.subBtnActive : ''}`}
                          onClick={() => { if (!isEditMode) setSelectedCategory(selectedParent); }}
                          disabled={isEditMode}
                        >
                          {selectedParent.name_ar} (عام)
                        </button>
                      )}
                    </div>
                  </>
                )}

                <div className={styles.navRow}>
                  <button
                    className={styles.btnPrimary}
                    disabled={!selectedCategory}
                    onClick={() => setStep(2)}
                  >
                    التالي ←
                  </button>
                </div>
              </div>
            )}

            {/* ── Step 2: Details ── */}
            {step === 2 && (
              <div className={styles.stepContent}>
                <h2 className={styles.stepTitle}>تفاصيل الإعلان</h2>
                <div className={styles.formGroup}>
                  <label className={styles.label}>عنوان الإعلان *</label>
                  <input
                    className={`${styles.input} ${errors.title ? styles.inputError : ''}`}
                    placeholder="مثال: تويوتا لاندكروزر 2022 — فل كامل"
                    value={title}
                    onChange={e => setTitle(e.target.value)}
                    maxLength={100}
                  />
                  <span className={styles.charCount}>{title.length}/100</span>
                  {errors.title && <p className={styles.errMsg}>{errors.title}</p>}
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.label}>الوصف *</label>
                  <textarea
                    className={`${styles.textarea} ${errors.description ? styles.inputError : ''}`}
                    placeholder="اكتب وصفاً دقيقاً للإعلان..."
                    value={description}
                    onChange={e => setDescription(e.target.value)}
                    rows={5}
                  />
                  <span className={styles.charCount}>{description.length}/5000</span>
                  {errors.description && <p className={styles.errMsg}>{errors.description}</p>}
                </div>

                <div className={styles.priceRow}>
                  <label className={styles.toggleLabel}>
                    <input type="checkbox" checked={isFree} onChange={e => setIsFree(e.target.checked)} />
                    مجاني
                  </label>
                  {!isFree && (
                    <div className={styles.priceInputWrap}>
                      <input
                        className={`${styles.input} ${styles.priceInput} ${errors.price ? styles.inputError : ''}`}
                        type="number"
                        placeholder="السعر (ريال سعودي)"
                        value={price}
                        onChange={e => setPrice(e.target.value)}
                        min={0}
                      />
                      <span className={styles.currency}>ر.س</span>
                    </div>
                  )}
                  <label className={styles.toggleLabel}>
                    <input type="checkbox" checked={isNegotiable} onChange={e => setIsNegotiable(e.target.checked)} disabled={isFree} />
                    قابل للتفاوض
                  </label>
                </div>
                {errors.price && <p className={styles.errMsg}>{errors.price}</p>}

                {/* Dynamic category fields */}
                {fields.length > 0 && (
                  <>
                    <h3 className={styles.subTitle}>معلومات إضافية</h3>
                    {fields.map(f => (
                      <div key={f.id} className={styles.formGroup}>
                        <label className={styles.label}>{f.label_ar}{f.is_required && ' *'}</label>
                        {f.field_type === 'select' && f.options ? (
                          <select
                            className={styles.input}
                            value={fieldValues[f.field_key] ?? ''}
                            onChange={e => setFieldValues(prev => ({ ...prev, [f.field_key]: e.target.value }))}
                          >
                            <option value="">اختر...</option>
                            {f.options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
                          </select>
                        ) : f.field_type === 'boolean' ? (
                          <select
                            className={styles.input}
                            value={fieldValues[f.field_key] ?? ''}
                            onChange={e => setFieldValues(prev => ({ ...prev, [f.field_key]: e.target.value }))}
                          >
                            <option value="">اختر...</option>
                            <option value="true">نعم</option>
                            <option value="false">لا</option>
                          </select>
                        ) : (
                          <input
                            className={styles.input}
                            type={f.field_type === 'number' || f.field_type === 'year' ? 'number' : 'text'}
                            placeholder={f.placeholder_ar ?? ''}
                            value={fieldValues[f.field_key] ?? ''}
                            onChange={e => setFieldValues(prev => ({ ...prev, [f.field_key]: e.target.value }))}
                          />
                        )}
                      </div>
                    ))}
                  </>
                )}

                <div className={styles.formGroup}>
                  <label className={styles.label}>رقم التواصل *</label>
                  <input className={`${styles.input} ${errors.contact_phone ? styles.inputError : ''}`} placeholder="05xxxxxxxx" value={phone} onChange={e => setPhone(e.target.value)} />
                  {errors.contact_phone && <p className={styles.errMsg}>{errors.contact_phone}</p>}
                </div>
                <div className={styles.formGroup}>
                  <label className={styles.label}>واتساب (اختياري)</label>
                  <input className={styles.input} placeholder="05xxxxxxxx" value={whatsapp} onChange={e => setWhatsapp(e.target.value)} />
                </div>

                <div className={styles.navRow}>
                  <button className={styles.btnSecondary} onClick={() => setStep(1)}>→ السابق</button>
                  <button className={styles.btnPrimary} disabled={!title || !description || !phone} onClick={() => setStep(3)}>التالي ←</button>
                </div>
              </div>
            )}

            {/* ── Step 3: Images ── */}
            {step === 3 && (
              <div className={styles.stepContent}>
                <h2 className={styles.stepTitle}>صور الإعلان</h2>
                <p className={styles.hint}>أضف من 1 إلى 10 صور (JPG، PNG، WebP) — الحد الأقصى 5 ميجا لكل صورة</p>
                <div className={styles.imageGrid}>
                  {/* Existing images (edit mode) */}
                  {existingImages.map((img, i) => {
                    if (removeImageIds.includes(img.id)) return null;
                    return (
                      <div key={`existing-${img.id}`} className={styles.imageThumb}>
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={img.url} alt={`صورة ${i + 1}`} className={styles.thumbImg} />
                        {i === 0 && imageFiles.length === 0 && <span className={styles.primaryBadge}>رئيسية</span>}
                        <button className={styles.removeImg} onClick={() => removeExistingImage(img.id)}>✕</button>
                      </div>
                    );
                  })}
                  {/* New image previews */}
                  {imagePreviews.map((src, i) => (
                    <div key={`new-${i}`} className={styles.imageThumb}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={src} alt={`صورة جديدة ${i + 1}`} className={styles.thumbImg} />
                      {existingImages.filter(img => !removeImageIds.includes(img.id)).length === 0 && i === 0 && <span className={styles.primaryBadge}>رئيسية</span>}
                      <button className={styles.removeImg} onClick={() => removeNewImage(i)}>✕</button>
                    </div>
                  ))}
                  {totalImages < 10 && (
                    <label className={styles.addImageBtn}>
                      <span>+</span>
                      <small>إضافة صورة</small>
                      <input type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={handleImageAdd} />
                    </label>
                  )}
                </div>
                {errors['images'] && <p className={styles.errMsg}>{errors['images']}</p>}
                <div className={styles.navRow}>
                  <button className={styles.btnSecondary} onClick={() => setStep(2)}>→ السابق</button>
                  <button className={styles.btnPrimary} disabled={totalImages === 0} onClick={() => setStep(4)}>التالي ←</button>
                </div>
              </div>
            )}

            {/* ── Step 4: Location ── */}
            {step === 4 && (
              <div className={styles.stepContent}>
                <h2 className={styles.stepTitle}>موقع الإعلان</h2>
                <div className={styles.formGroup}>
                  <label className={styles.label}>المنطقة *</label>
                  <select className={styles.input} value={selectedRegion?.id ?? ''} onChange={e => {
                    const r = regions.find(x => x.id === Number(e.target.value)) ?? null;
                    setSelectedRegion(r);
                    setSelectedCity(null);
                  }}>
                    <option value="">اختر المنطقة...</option>
                    {regions.map(r => <option key={r.id} value={r.id}>{r.name_ar}</option>)}
                  </select>
                </div>
                {cities.length > 0 && (
                  <div className={styles.formGroup}>
                    <label className={styles.label}>المدينة *</label>
                    <select className={styles.input} value={selectedCity?.id ?? ''} onChange={e => {
                      setSelectedCity(cities.find(c => c.id === Number(e.target.value)) ?? null);
                    }}>
                      <option value="">اختر المدينة...</option>
                      {cities.map(c => <option key={c.id} value={c.id}>{c.name_ar}</option>)}
                    </select>
                  </div>
                )}
                <div className={styles.navRow}>
                  <button className={styles.btnSecondary} onClick={() => setStep(3)}>→ السابق</button>
                  <button className={styles.btnPrimary} disabled={!selectedCity} onClick={() => setStep(5)}>التالي ←</button>
                </div>
              </div>
            )}

            {/* ── Step 5: Preview & Submit ── */}
            {step === 5 && (
              <div className={styles.stepContent}>
                <h2 className={styles.stepTitle}>مراجعة الإعلان</h2>
                <div className={styles.previewCard}>
                  {(imagePreviews[0] || existingImages[0]) && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={imagePreviews[0] || existingImages[0]?.url} alt="الصورة الرئيسية" className={styles.previewImg} />
                  )}
                  <div className={styles.previewBody}>
                    <h3 className={styles.previewTitle}>{title}</h3>
                    <p className={styles.previewPrice}>
                      {isFree ? 'مجاني' : `${Number(price).toLocaleString('ar-SA')} ر.س`}
                      {isNegotiable && <span className={styles.negBadge}>قابل للتفاوض</span>}
                    </p>
                    <p className={styles.previewMeta}>{selectedCategory?.name_ar} • {selectedCity?.name_ar}، {selectedRegion?.name_ar}</p>
                    <p className={styles.previewDesc}>{description.slice(0, 200)}{description.length > 200 ? '...' : ''}</p>
                  </div>
                </div>

                {/* Commission preview */}
                {commission && !commission.is_free && commission.commission_amount > 0 && (
                  <div className={styles.commissionBox}>
                    <div className={styles.commissionHeader}>
                      <span className={styles.commissionIcon}>💰</span>
                      <span className={styles.commissionTitle}>العمولة المقدرة</span>
                    </div>
                    <div className={styles.commissionAmount}>
                      {commission.commission_amount.toLocaleString('ar-SA')} ر.س
                    </div>
                    <p className={styles.commissionNote}>{commission.note}</p>
                  </div>
                )}

                {!isEditMode && (
                  <label className={styles.pledgeLabel}>
                    <input type="checkbox" checked={pledgeAccepted} onChange={e => setPledgeAccepted(e.target.checked)} />
                    أقر بأن هذا الإعلان حقيقي وأوافق على شروط الاستخدام وسياسة الخصوصية
                  </label>
                )}

                <div className={styles.navRow}>
                  <button className={styles.btnSecondary} onClick={() => setStep(4)}>→ السابق</button>
                  <button
                    className={styles.btnPublish}
                    disabled={(isEditMode ? false : !pledgeAccepted) || submitting}
                    onClick={handleSubmit}
                  >
                    {submitting ? 'جارٍ الحفظ...' : isEditMode ? '💾 حفظ التعديلات' : '🚀 نشر الإعلان'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
