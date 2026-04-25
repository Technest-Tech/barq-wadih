'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowRight, Send, ImagePlus, X } from 'lucide-react';
import { doc, getDoc } from 'firebase/firestore';
import { ref as storageRef, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { getStorage } from 'firebase/storage';
import { getApp } from 'firebase/app';
import { db } from '@/lib/firebase/firestore';
import { useMessages } from '@/lib/hooks/useMessages';
import { useFirebaseAuth } from '@/lib/hooks/useFirebaseAuth';
import { useAuthStore } from '@/store/auth.store';
import { notifyNewMessage } from '@/lib/api/chat';
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

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ConversationPage() {
  const { conversationId, locale } = useParams<{ conversationId: string; locale: string }>();
  const router = useRouter();
  const { user } = useAuthStore();
  useFirebaseAuth(); // ensure Firebase sign-in is ready

  const { messages, loading, sendMessage, sendImage } = useMessages(conversationId);

  const [text, setText]               = useState('');
  const [convMeta, setConvMeta]        = useState<Record<string, string> | null>(null);
  const [imgUploading, setImgUploading] = useState(false);
  const [imgPreview, setImgPreview]    = useState<string | null>(null);

  const bottomRef  = useRef<HTMLDivElement>(null);
  const fileRef    = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const myId = String(user?.id ?? '');

  // Load conversation metadata (ad info, participants)
  useEffect(() => {
    if (!conversationId) return;
    getDoc(doc(db, 'conversations', conversationId)).then(snap => {
      if (snap.exists()) setConvMeta(snap.data() as Record<string, string>);
    });
  }, [conversationId]);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length]);

  // Auto-resize textarea
  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setText(e.target.value);
    e.target.style.height = 'auto';
    e.target.style.height = `${Math.min(e.target.scrollHeight, 120)}px`;
  };

  const getOtherParticipantId = (): string => {
    if (!convMeta) return '';
    const ids = (convMeta.participantIds as unknown as string[]) ?? [];
    return ids.find(id => id !== myId) ?? '';
  };

  const handleSend = async () => {
    if (!text.trim() || !convMeta) return;
    const preview     = text.trim();
    const receiverId  = parseInt(getOtherParticipantId(), 10);
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

    // Show preview immediately
    const previewUrl = URL.createObjectURL(file);
    setImgPreview(previewUrl);
    setImgUploading(true);

    try {
      const storage  = getStorage(getApp());
      const path     = `chat_images/${conversationId}/${Date.now()}_${file.name}`;
      const sRef     = storageRef(storage, path);
      const task     = uploadBytesResumable(sRef, file);

      await new Promise<void>((resolve, reject) => {
        task.on('state_changed', null, reject, resolve);
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

  // Date separator logic
  const renderMessages = useCallback(() => {
    const elements: React.ReactNode[] = [];
    let lastDate = '';

    messages.forEach((msg, i) => {
      const secs       = msg.createdAt?._seconds ?? 0;
      const dateLabel  = formatDateSeparator(secs);
      const isMe       = msg.senderId === myId;

      if (dateLabel !== lastDate) {
        lastDate = dateLabel;
        elements.push(
          <div key={`sep-${i}`} className={styles.dateSep}>
            <span>{dateLabel}</span>
          </div>
        );
      }

      if (msg.type === 'image' && msg.imageUrl) {
        elements.push(
          <div key={msg.id} className={`${styles.bubble} ${isMe ? styles.sent : styles.received}`}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={msg.imageUrl} alt="صورة" className={styles.chatImg} />
            <span className={styles.msgTime}>{formatTime(secs)}</span>
          </div>
        );
      } else {
        elements.push(
          <div key={msg.id} className={`${styles.bubble} ${isMe ? styles.sent : styles.received}`}>
            <p className={styles.msgText}>{msg.text}</p>
            <span className={styles.msgTime}>{formatTime(secs)}</span>
          </div>
        );
      }
    });

    return elements;
  }, [messages, myId]);

  const adHref = convMeta?.adId ? `/${locale}/ads/${convMeta.adId}` : '#';

  return (
    <div className={styles.page} dir="rtl">

      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <header className={styles.header}>
        <button className={styles.backBtn} onClick={() => router.back()} aria-label="رجوع">
          <ArrowRight size={20} />
        </button>
        <Link href={adHref} className={styles.adInfo}>
          {convMeta?.adImage && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={convMeta.adImage} alt="" className={styles.adThumb} />
          )}
          <div className={styles.adText}>
            <span className={styles.adTitle}>{convMeta?.adTitle ?? '...'}</span>
            <span className={styles.adSub}>اضغط لعرض الإعلان</span>
          </div>
        </Link>
      </header>

      {/* ── Messages area ──────────────────────────────────────────────────── */}
      <div className={styles.messagesArea}>
        {loading ? (
          <div className={styles.loadingState}>جارٍ تحميل الرسائل...</div>
        ) : messages.length === 0 ? (
          <div className={styles.emptyConv}>
            <p>ابدأ المحادثة!</p>
            <span>لا توجد رسائل بعد</span>
          </div>
        ) : (
          renderMessages()
        )}

        {/* Image upload preview */}
        {imgPreview && (
          <div className={`${styles.bubble} ${styles.sent}`}>
            <div className={styles.imgUploadWrap}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={imgPreview} alt="جارٍ الرفع..." className={styles.chatImg} />
              {imgUploading && <div className={styles.uploadOverlay}>⏫</div>}
            </div>
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* ── Input bar ──────────────────────────────────────────────────────── */}
      <div className={styles.inputBar}>
        {/* Image button */}
        <button
          className={styles.imgBtn}
          onClick={() => fileRef.current?.click()}
          disabled={imgUploading}
          aria-label="إرسال صورة"
        >
          {imgUploading ? '⏳' : <ImagePlus size={20} />}
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleImagePick}
        />

        {/* Text input */}
        <textarea
          ref={textareaRef}
          className={styles.textInput}
          placeholder="اكتب رسالتك..."
          rows={1}
          value={text}
          onChange={handleTextChange}
          onKeyDown={handleKeyDown}
        />

        {/* Send button */}
        <button
          className={styles.sendBtn}
          onClick={handleSend}
          disabled={!text.trim()}
          aria-label="إرسال"
        >
          <Send size={18} />
        </button>
      </div>
    </div>
  );
}
