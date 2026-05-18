'use client';

import { useEffect, useState } from 'react';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import {
  fetchContactCategories,
  submitContact,
  type ContactCategory,
} from '@/lib/api/contact';
import styles from './page.module.css';

// ── FAQ accordion ─────────────────────────────────────────────────────────────

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(true);
  return (
    <div className={styles.faqItem}>
      <button className={styles.faqQ} onClick={() => setOpen(!open)}>
        <span>{q}</span>
        <span className={styles.faqArrow}>{open ? '▲' : '▼'}</span>
      </button>
      {open && <p className={styles.faqA}>{a}</p>}
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ContactPage() {
  const [categories, setCategories] = useState<ContactCategory[]>([]);
  const [selected, setSelected] = useState<ContactCategory | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [loading, setLoading] = useState(true);

  // Form state
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchContactCategories()
      .then(setCategories)
      .finally(() => setLoading(false));
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!selected) { setError('الرجاء اختيار سبب التواصل'); return; }
    setError('');
    setSubmitting(true);
    try {
      await submitContact({
        name, email,
        phone: phone || undefined,
        category: selected.slug,
        message,
      });
      setSubmitted(true);
      setName(''); setEmail(''); setPhone(''); setMessage(''); setSelected(null);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'حدث خطأ، حاول مجدداً');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <>
      <Header />

      {/* ── Hero ── */}
      <div className={styles.hero}>
        <h1 className={styles.heroTitle}>تواصل معنا</h1>
        <p className={styles.heroSub}>نحن هنا لمساعدتك — ابحث في الأسئلة الشائعة أو أرسل رسالتك مباشرة</p>
      </div>

      <main className={styles.page}>
        <div className={styles.container}>
          {/* ── Main card ── */}
          <div className={styles.card}>
            <div className={styles.cardHeader}>
              <h1 className={styles.title}>الأسئلة الشائعة</h1>
            </div>

            {/* Category dropdown */}
            <div className={styles.dropdownWrap}>
              <select
                className={styles.dropdown}
                value={selected?.slug ?? ''}
                onChange={(e) => {
                  const cat = categories.find(c => c.slug === e.target.value) ?? null;
                  setSelected(cat);
                  setShowAll(false);
                }}
              >
                <option value="">إختار السبب</option>
                {categories.map(c => (
                  <option key={c.slug} value={c.slug}>{c.label}</option>
                ))}
              </select>
            </div>

            {/* FAQs for selected category */}
            {selected && (
              <div className={styles.faqSection}>
                {selected.faqs.map((faq, i) => (
                  <FaqItem key={i} q={faq.q} a={faq.a} />
                ))}
              </div>
            )}

            {/* Show all FAQs link */}
            {!loading && (
              <button
                className={styles.showAllBtn}
                onClick={() => setShowAll(!showAll)}
              >
                {showAll ? 'إخفاء الأسئلة الشائعة' : 'عرض جميع الأسئلة الشائعة'}
              </button>
            )}

            {/* All FAQs expanded */}
            {showAll && !selected && (
              <div className={styles.allFaqs}>
                {categories.map(cat => (
                  <div key={cat.slug} className={styles.catGroup}>
                    <h3 className={styles.catLabel}>{cat.label}</h3>
                    {cat.faqs.map((faq, i) => (
                      <FaqItem key={i} q={faq.q} a={faq.a} />
                    ))}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* ── Contact form (shown after selecting a category) ── */}
          {selected && (
            <div className={styles.card} style={{ marginTop: '1.5rem' }}>
              <h2 className={styles.formTitle}>أرسل لنا رسالة</h2>

              {submitted && (
                <div className={styles.successBox}>
                  تم إرسال رسالتك بنجاح. سيتواصل معك فريق الدعم قريباً.
                </div>
              )}

              {error && <div className={styles.errorBox}>{error}</div>}

              <form onSubmit={handleSubmit} className={styles.form}>
                <div className={styles.row}>
                  <div className={styles.field}>
                    <label>الاسم الكامل *</label>
                    <input
                      required
                      value={name}
                      onChange={e => setName(e.target.value)}
                      placeholder="أدخل اسمك الكامل"
                    />
                  </div>
                  <div className={styles.field}>
                    <label>البريد الإلكتروني *</label>
                    <input
                      required
                      type="email"
                      value={email}
                      onChange={e => setEmail(e.target.value)}
                      placeholder="example@email.com"
                    />
                  </div>
                </div>
                <div className={styles.field}>
                  <label>رقم الجوال (اختياري)</label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={e => setPhone(e.target.value)}
                    placeholder="+966 5X XXX XXXX"
                  />
                </div>
                <div className={styles.field}>
                  <label>رسالتك *</label>
                  <textarea
                    required
                    rows={5}
                    minLength={10}
                    value={message}
                    onChange={e => setMessage(e.target.value)}
                    placeholder="اكتب رسالتك هنا..."
                  />
                </div>
                <button
                  type="submit"
                  disabled={submitting}
                  className={styles.submitBtn}
                >
                  {submitting ? 'جارٍ الإرسال...' : 'إرسال الرسالة'}
                </button>
              </form>
            </div>
          )}
        </div>
      </main>
      <Footer />
    </>
  );
}
