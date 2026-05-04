'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowRight, Send, ImagePlus, Mic, MoreVertical, Check, CheckCheck, ShoppingBag } from 'lucide-react';
import { doc, getDoc } from 'firebase/firestore';
import { ref as storageRef, uploadBytesResumable, getDownloadURL, getStorage } from 'firebase/storage';
import { getApp } from 'firebase/app';
import { db } from '@/lib/firebase/firestore';
import { useMessages } from '@/lib/hooks/useMessages';
import { useFirebaseAuth } from '@/lib/hooks/useFirebaseAuth';
import { useAuthStore } from '@/store/auth.store';
import { notifyNewMessage } from '@/lib/api/chat';
import { resolveStorageUrl } from '@/lib/storageUrl';
import styles from './page.module.css';

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatTime(secs: number): string {
  return new Date(secs * 1000).toLocaleTimeString('ar-SA', {
    hour: '2-digit', minute: '2-digit',
  });
}

function formatDateSeparator(secs: number): string {
  const d    = new Date(secs * 1000);
  const now  = new Date();
  const diff = Math.floor((now.getTime() - d.getTime()) / 86400000);
  if (diff === 0) return 'اليوم';
  if (diff === 1) return 'أمس';
  return d.toLocaleDateString('ar-SA', { day: 'numeric', month: 'long' });
}

interface ConvMeta {
  adId?: string;
  adTitle?: string;
  adImage?: string;
  participantIds?: string[];
  participantNames?: Record<string, string>;
  participantAvatars?: Record<string, string | null>;
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ConversationPage() {
  const { conversationId, locale } = useParams<{ conversationId: string; locale: string }>();
  const router = useRouter();
  const { user } = useAuthStore();
  const { isReady: firebaseReady } = useFirebaseAuth();

  // Pass null until Firebase Auth is stable; useMessages treats null as "not open".
  const { messages, loading, sendMessage, sendImage } = useMessages(firebaseReady ? conversationId : null);

  const [text, setText]                 = useState('');
  const [convMeta, setConvMeta]         = useState<ConvMeta | null>(null);
  const [imgUploading, setImgUploading] = useState(false);
  const [imgPreview, setImgPreview]     = useState<string | null>(null);

  const bottomRef   = useRef<HTMLDivElement>(null);
  const fileRef     = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const myId = String(user?.id ?? '');

  // Load conversation metadata (ad info, participants)
  useEffect(() => {
    if (!conversationId) return;
    getDoc(doc(db, 'conversations', conversationId)).then(snap => {
      if (snap.exists()) setConvMeta(snap.data() as ConvMeta);
    }).catch(() => {});
  }, [conversationId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length, imgPreview]);

  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setText(e.target.value);
    e.target.style.height = 'auto';
    e.target.style.height = `${Math.min(e.target.scrollHeight, 120)}px`;
  };

  const getOtherParticipantId = (): string => {
    const ids = convMeta?.participantIds ?? [];
    return ids.find(id => id !== myId) ?? '';
  };

  const handleSend = async () => {
    const preview = text.trim();
    if (!preview || !convMeta) return;
    const receiverId = parseInt(getOtherParticipantId(), 10);
    setText('');
    if (textareaRef.current) textareaRef.current.style.height = 'auto';
    await sendMessage(preview);
    if (receiverId) notifyNewMessage(conversationId, receiverId, preview).catch(() => {});
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleImagePick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const previewUrl = URL.createObjectURL(file);
    setImgPreview(previewUrl);
    setImgUploading(true);

    try {
      const storage = getStorage(getApp());
      const path    = `chat_images/${conversationId}/${Date.now()}_${file.name}`;
      const sRef    = storageRef(storage, path);
      const task    = uploadBytesResumable(sRef, file);

      await new Promise<void>((resolve, reject) => {
        task.on('state_changed', null, reject, () => resolve());
      });

      const downloadUrl = await getDownloadURL(task.snapshot.ref);
      const receiverId  = parseInt(getOtherParticipantId(), 10);

      await sendImage(downloadUrl);
      if (receiverId) notifyNewMessage(conversationId, receiverId, '📷 صورة').catch(() => {});
    } finally {
      setImgUploading(false);
      setImgPreview(null);
      URL.revokeObjectURL(previewUrl);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const renderMessages = useCallback(() => {
    const elements: React.ReactNode[] = [];
    let lastDate = '';

    messages.forEach((msg, i) => {
      const secs      = msg.createdAt?._seconds ?? 0;
      const dateLabel = formatDateSeparator(secs);
      const isMe      = msg.senderId === myId;

      if (dateLabel !== lastDate) {
        lastDate = dateLabel;
        elements.push(
          <div key={`sep-${i}`} className={styles.dateSep}>
            <span>{dateLabel}</span>
          </div>
        );
      }

      const tickIcon = isMe
        ? (msg.isRead
            ? <CheckCheck size={14} className={styles.tickRead} />
            : <Check size={14} className={styles.tickSent} />)
        : null;

      if (msg.type === 'image' && msg.imageUrl) {
        elements.push(
          <div key={msg.id} className={`${styles.bubbleRow} ${isMe ? styles.rowSent : styles.rowReceived}`}>
            <div className={`${styles.bubble} ${isMe ? styles.sent : styles.received}`}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={msg.imageUrl} alt="صورة" className={styles.chatImg} />
              <div className={styles.metaRow}>
                <span className={styles.msgTime}>{formatTime(secs)}</span>
                {tickIcon}
              </div>
            </div>
          </div>
        );
      } else {
        elements.push(
          <div key={msg.id} className={`${styles.bubbleRow} ${isMe ? styles.rowSent : styles.rowReceived}`}>
            <div className={`${styles.bubble} ${isMe ? styles.sent : styles.received}`}>
              <p className={styles.msgText}>{msg.text}</p>
              <div className={styles.metaRow}>
                <span className={styles.msgTime}>{formatTime(secs)}</span>
                {tickIcon}
              </div>
            </div>
          </div>
        );
      }
    });

    return elements;
  }, [messages, myId]);

  const adHref     = convMeta?.adId ? `/${locale}/ads/${convMeta.adId}` : '#';
  const otherId    = convMeta?.participantIds?.find(id => id !== myId);
  const peerName   = (otherId && convMeta?.participantNames?.[otherId])
    || convMeta?.adTitle
    || '...';
  const peerAvatar = resolveStorageUrl(
    (otherId && convMeta?.participantAvatars?.[otherId]) || null
  );
  const initial    = peerName.trim().charAt(0).toUpperCase() || '?';
  const canSend    = text.trim().length > 0;

  return (
    <div className={styles.page} dir="rtl">

      {/* Header strip — peer avatar, ad title, back, kebab */}
      <header className={styles.header}>
        <button
          className={styles.backBtn}
          onClick={() => router.push(`/${locale}/messages`)}
          aria-label="رجوع"
          type="button"
        >
          <ArrowRight size={20} />
        </button>

        <Link href={adHref} className={styles.adInfo}>
          <div className={styles.headAvatar}>
            {peerAvatar ? (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img src={peerAvatar} alt="" className={styles.headAvatarImg} />
            ) : (
              <span>{initial}</span>
            )}
          </div>
          <div className={styles.adText}>
            <span className={styles.adTitle}>{peerName}</span>
            <span className={styles.adSub}>
              {convMeta?.adTitle ? `بخصوص: ${convMeta.adTitle}` : 'اضغط لعرض الإعلان'}
            </span>
          </div>
        </Link>

        <button className={styles.kebabBtn} type="button" aria-label="المزيد" disabled>
          <MoreVertical size={18} />
        </button>
      </header>

      {/* Messages canvas */}
      <div className={styles.canvas}>
        <div className={styles.messagesArea}>
          {convMeta?.adId && (
            <Link href={adHref} className={styles.adCard}>
              {convMeta.adImage ? (
                /* eslint-disable-next-line @next/next/no-img-element */
                <img src={resolveStorageUrl(convMeta.adImage) ?? ''} alt="" className={styles.adCardImg} />
              ) : (
                <div className={styles.adCardImgFallback}>
                  <ShoppingBag size={22} />
                </div>
              )}
              <div className={styles.adCardBody}>
                <span className={styles.adCardLabel}>المحادثة بخصوص</span>
                <span className={styles.adCardTitle}>{convMeta.adTitle ?? 'الإعلان'}</span>
              </div>
              <span className={styles.adCardCta}>عرض الإعلان ←</span>
            </Link>
          )}

          {loading ? (
            <div className={styles.loadingState}>جارٍ تحميل الرسائل...</div>
          ) : messages.length === 0 ? (
            <div className={styles.emptyConv}>
              <p>ابدأ المحادثة!</p>
              <span>لا توجد رسائل بعد — اكتب أول رسالة في الأسفل.</span>
            </div>
          ) : (
            renderMessages()
          )}

          {imgPreview && (
            <div className={`${styles.bubbleRow} ${styles.rowSent}`}>
              <div className={`${styles.bubble} ${styles.sent}`}>
                <div className={styles.imgUploadWrap}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={imgPreview} alt="جارٍ الرفع..." className={styles.chatImg} />
                  {imgUploading && <div className={styles.uploadOverlay}>⏫</div>}
                </div>
              </div>
            </div>
          )}

          <div ref={bottomRef} />
        </div>
      </div>

      {/* Composer */}
      <div className={styles.inputBar}>
        <button
          className={styles.iconBtn}
          onClick={() => fileRef.current?.click()}
          disabled={imgUploading}
          aria-label="إرسال صورة"
          type="button"
        >
          <ImagePlus size={20} />
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleImagePick}
        />

        <textarea
          ref={textareaRef}
          className={styles.textInput}
          placeholder="اكتب رسالتك هنا…"
          rows={1}
          value={text}
          onChange={handleTextChange}
          onKeyDown={handleKeyDown}
        />

        {canSend ? (
          <button
            className={styles.sendBtn}
            onClick={handleSend}
            aria-label="إرسال"
            type="button"
          >
            <Send size={18} />
          </button>
        ) : (
          <button className={styles.iconBtn} aria-label="تسجيل صوتي" disabled type="button">
            <Mic size={20} />
          </button>
        )}
      </div>
    </div>
  );
}
