'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { motion, AnimatePresence, type Variants } from 'framer-motion';
import { Mail, Lock, Eye, EyeOff, Loader2, AlertCircle, X } from 'lucide-react';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './AuthModal.module.css';

const emailSchema = z.object({
  email: z.string().min(1, 'البريد مطلوب').email('البريد غير صالح'),
  password: z.string().min(1, 'كلمة المرور مطلوبة'),
});
type EmailForm = z.infer<typeof emailSchema>;

const bgVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1 },
};

const modalVariants: Variants = {
  hidden: { opacity: 0, scale: 0.95, y: 20 },
  visible: {
    opacity: 1,
    scale: 1,
    y: 0,
    transition: { type: 'spring', damping: 25, stiffness: 300 },
  },
  exit: { opacity: 0, scale: 0.95, y: -20, transition: { duration: 0.2 } },
};

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

export default function AuthModal({ isOpen, onClose, onSuccess }: AuthModalProps) {
  const [showPass, setShowPass] = useState(false);
  const [error, setError] = useState('');

  const { setAuth } = useAuthStore();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<EmailForm>({ resolver: zodResolver(emailSchema) });

  const handleClose = () => {
    reset();
    setError('');
    onClose();
  };

  const onSubmit = async (data: EmailForm) => {
    setError('');
    try {
      const res = await authApi.login(data);
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        onSuccess?.();
        handleClose();
      }
    } catch (err) {
      setError(err instanceof ApiClientError ? err.message : 'حدث خطأ. حاول مرة أخرى.');
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        className={styles.overlay}
        variants={bgVariants}
        initial="hidden"
        animate="visible"
        exit="hidden"
        onClick={handleClose}
      >
        <motion.div
          className={styles.modal}
          variants={modalVariants}
          initial="hidden"
          animate="visible"
          exit="exit"
          onClick={(e) => e.stopPropagation()}
        >
          <button className={styles.closeBtn} onClick={handleClose}>
            <X size={18} />
          </button>

          <div className={styles.header}>
            <h2 className={styles.title}>مرحباً بك 👋</h2>
            <p className={styles.subtitle}>سجّل دخولك للمتابعة</p>
          </div>

          <div className={styles.body}>
            <AnimatePresence>
              {error && (
                <motion.div
                  className={styles.errorBanner}
                  initial={{ opacity: 0, y: -8, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.97 }}
                  transition={{ duration: 0.2 }}
                >
                  <AlertCircle size={16} /> {error}
                </motion.div>
              )}
            </AnimatePresence>

            <form onSubmit={handleSubmit(onSubmit)} noValidate>
              <div className={styles.fieldGroup}>
                <div className={styles.field}>
                  <label className={styles.label}>البريد الإلكتروني</label>
                  <div className={styles.inputWrap}>
                    <Mail size={17} className={styles.inputIconLtr} />
                    <input
                      className={`${styles.input} ${styles.inputLtr} ${errors.email ? styles.inputError : ''}`}
                      type="email"
                      placeholder="you@example.com"
                      {...register('email')}
                    />
                  </div>
                  {errors.email && (
                    <span className={styles.fieldError}>{errors.email.message}</span>
                  )}
                </div>

                <div className={styles.field}>
                  <label className={styles.label}>كلمة المرور</label>
                  <div className={styles.inputWrap}>
                    <Lock size={17} className={styles.inputIconLtr} />
                    <input
                      className={`${styles.input} ${styles.inputLtr} ${errors.password ? styles.inputError : ''}`}
                      type={showPass ? 'text' : 'password'}
                      placeholder="••••••••"
                      style={{ paddingLeft: '44px', paddingRight: '44px' }}
                      {...register('password')}
                    />
                    <button
                      type="button"
                      className={styles.eyeBtn}
                      onClick={() => setShowPass((p) => !p)}
                    >
                      {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                  {errors.password && (
                    <span className={styles.fieldError}>{errors.password.message}</span>
                  )}
                </div>

                <button className={styles.btnPrimary} type="submit" disabled={isSubmitting}>
                  {isSubmitting ? <Loader2 size={18} className={styles.spinner} /> : 'دخول'}
                </button>
              </div>
            </form>
          </div>

          <p className={styles.footer}>
            ليس لديك حساب؟{' '}
            <Link href={`/${locale}/register`} className={styles.footerLink} onClick={handleClose}>
              إنشاء حساب مجاني
            </Link>
          </p>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
