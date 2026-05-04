// User types shared across the frontend
export interface UserRegion {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
}

export interface AuthUser {
  id: number;
  name: string;
  email: string | null;
  phone: string | null;
  /** The Firebase UID that the backend mints for this user. The frontend
   *  compares this to firebaseAuth.currentUser?.uid to detect stale sessions. */
  firebase_uid: string;
  avatar_url: string | null;
  cover_image_url: string | null;
  bio: string | null;
  role: 'user' | 'admin' | 'super_admin';
  locale: 'ar' | 'en';
  is_verified: boolean;
  is_dealer: boolean;
  is_active: boolean;
  avg_rating: string;
  rating_count: number;
  total_ads_count: number;
  phone_verified_at: string | null;
  email_verified_at: string | null;
  unread_notifications_count: number;
  region: UserRegion | null;
  city: UserRegion | null;
  created_at: string;
}

export interface AuthResponse {
  token: string;
  user: AuthUser;
  is_new?: boolean;
}
