'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { firebaseConfig } from './config';

// Reuse the same Firebase app instance as auth.ts
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

/** Firestore client — singleton, safe for Next.js hot reload */
export const db = getFirestore(app);
