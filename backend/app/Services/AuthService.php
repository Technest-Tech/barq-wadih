<?php

namespace App\Services;

use App\Contracts\ChatDataEraser;
use App\DTOs\RegisterData;
use App\DTOs\UpdateProfileData;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function __construct(
        private readonly ImageService $imageService,
        private readonly ChatDataEraser $chatDataEraser,
    ) {}
    // ── Registration ─────────────────────────────────────────────────────────

    public function register(RegisterData $data): array
    {
        $user = User::create([
            'name' => $data->name,
            'phone' => $data->phone,
            'email' => $data->email,
            'password' => $data->password ? Hash::make($data->password) : null,
            'region_id' => $data->regionId,
            'city_id' => $data->cityId,
            'locale' => $data->locale,
            'role' => UserRole::User,
            'is_active' => true,
        ]);

        $token = $user->createToken('api-token')->plainTextToken;

        return compact('user', 'token');
    }

    // ── Email + Password Login ────────────────────────────────────────────────

    public function loginWithPassword(string $email, string $password): array
    {
        $user = User::where('email', $email)->first();

        if (! $user || ! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['البريد الإلكتروني أو كلمة المرور غير صحيحة.'],
            ]);
        }

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'email' => ['حسابك موقوف. يرجى التواصل مع الدعم.'],
            ]);
        }

        // Update last active timestamp
        $user->update(['last_active_at' => now()]);

        $token = $user->createToken('api-token')->plainTextToken;

        return compact('user', 'token');
    }

    // ── Firebase Phone OTP Login ──────────────────────────────────────────────

    public function loginWithFirebaseToken(string $idToken, ?string $name = null, string $locale = 'ar'): array
    {
        try {
            // Verify the Firebase ID token
            $firebase = app('firebase.auth');
            $verifiedToken = $firebase->verifyIdToken($idToken);
            $firebaseUid = $verifiedToken->claims()->get('sub');
            $phone = $verifiedToken->claims()->get('phone_number');
        } catch (\Throwable $e) {
            throw ValidationException::withMessages([
                'firebase_id_token' => ['رمز التحقق غير صالح أو منتهي الصلاحية.'],
            ]);
        }

        if (! $phone) {
            throw ValidationException::withMessages([
                'firebase_id_token' => ['لم يتم التحقق من رقم الجوال.'],
            ]);
        }

        // Upsert: find by firebase_uid or phone → create if new
        $user = User::where('firebase_uid', $firebaseUid)
            ->orWhere('phone', $phone)
            ->first();

        if (! $user) {
            $user = User::create([
                'name' => $name ?? 'مستخدم '.Str::random(6),
                'phone' => $phone,
                'firebase_uid' => $firebaseUid,
                'phone_verified_at' => now(),
                'role' => UserRole::User,
                'locale' => $locale,
                'is_active' => true,
            ]);
        } else {
            // Sync firebase_uid and mark phone as verified
            $user->update([
                'firebase_uid' => $firebaseUid,
                'phone_verified_at' => $user->phone_verified_at ?? now(),
                'last_active_at' => now(),
            ]);
        }

        $token = $user->createToken('firebase-token')->plainTextToken;

        return compact('user', 'token');
    }

    // ── Profile Update ────────────────────────────────────────────────────────

    public function updateProfile(User $user, UpdateProfileData $data): User
    {
        $user->update($data->toArray());
        $user->load(['region', 'city']);

        return $user;
    }

    // ── Avatar Upload ─────────────────────────────────────────────────────────

    public function uploadAvatar(User $user, UploadedFile $file): User
    {
        if ($user->avatar) {
            $this->imageService->delete($user->avatar);
        }

        $path = $this->imageService->store($file, "avatars/{$user->id}");
        $user->update(['avatar' => $this->imageService->url($path)]);

        return $user;
    }

    // ── Cover Image Upload ────────────────────────────────────────────────────

    public function uploadCoverImage(User $user, UploadedFile $file): User
    {
        if ($user->cover_image) {
            $this->imageService->delete($user->cover_image);
        }

        $path = $this->imageService->store($file, "covers/{$user->id}");
        $user->update(['cover_image' => $this->imageService->url($path)]);

        return $user;
    }

    // ── Account deletion ─────────────────────────────────────────────────────

    public function deleteAccount(User $user): void
    {
        // Two Firebase identities can exist for one account. `firebase_uid` is
        // only set by the legacy phone-OTP path, while chat always signs in with
        // strval($user->id) (see ChatService::mintCustomToken) — so an
        // email-only account has a live Firebase identity that firebase_uid
        // never records. Revoke both, or a stale Firebase session outlives the
        // deleted account.
        $firebaseUids = array_values(array_unique(array_filter([
            (string) $user->id,
            $user->firebase_uid,
        ])));
        $avatar = $user->avatar;
        $cover = $user->cover_image;

        // Chat lives outside the SQL transaction. It must be erased first so
        // the API never reports success while account-linked chat data remains.
        $this->chatDataEraser->eraseForUser((int) $user->id);

        DB::transaction(function () use ($user): void {
            // Financial rows and reports may have statutory retention duties.
            // They stay linked to the soft-deleted user, while public/profile
            // content and authentication credentials are removed immediately.
            $user->tokens()->delete();
            $user->devices()->delete();
            $user->favorites()->delete();
            $user->categoryFollows()->delete();
            $user->sellerFollows()->delete();
            $user->followers()->delete();
            $user->notifications()->delete();
            $user->blockedUsers()->detach();
            $user->blockedByUsers()->detach();

            // Remove the account holder's non-financial contributions and
            // device/session traces. Reports and financial/subscription rows
            // are retained against the anonymised soft-deleted account for
            // fraud, moderation, and statutory record-keeping only.
            if ($user->email) {
                DB::table('password_reset_tokens')->where('email', $user->email)->delete();
            }
            DB::table('sessions')->where('user_id', $user->id)->delete();
            DB::table('search_logs')->where('user_id', $user->id)->delete();
            DB::table('banner_clicks')->where('user_id', $user->id)->update(['user_id' => null]);
            DB::table('contact_submissions')->where('user_id', $user->id)->delete();
            DB::table('ad_questions')->where('user_id', $user->id)->delete();
            DB::table('ratings')->where('rater_id', $user->id)->delete();

            // Marketplace content disappears from all public feeds at once.
            foreach ($user->ads()->get() as $ad) {
                foreach ($ad->images as $image) {
                    $this->imageService->delete($image->image_url);
                    if ($image->thumbnail_url) {
                        $this->imageService->delete($image->thumbnail_url);
                    }
                    $image->delete();
                }
                $ad->fieldValues()->delete();
                $ad->forceFill([
                    'title' => 'محتوى محذوف',
                    'description' => 'تم حذف هذا المحتوى بناءً على طلب صاحب الحساب.',
                    'contact_phone' => null,
                    'contact_whatsapp' => null,
                    'district_name_free' => null,
                    'latitude' => null,
                    'longitude' => null,
                    'show_phone_publicly' => false,
                ])->saveQuietly();
                $ad->delete();
            }

            $user->forceFill([
                'name' => 'حساب محذوف',
                'username' => 'deleted_'.$user->id.'_'.Str::lower(Str::random(6)),
                'email' => null,
                'phone' => null,
                'password' => null,
                'avatar' => null,
                'cover_image' => null,
                'bio' => null,
                'region_id' => null,
                'city_id' => null,
                'firebase_uid' => null,
                'phone_verified_at' => null,
                'email_verified_at' => null,
                'is_active' => false,
                'remember_token' => null,
            ])->saveQuietly();

            $user->delete();
        });

        if ($avatar) {
            $this->imageService->delete($avatar);
        }
        if ($cover) {
            $this->imageService->delete($cover);
        }

        foreach ($firebaseUids as $uid) {
            try {
                app('firebase.auth')->deleteUser($uid);
            } catch (\Throwable) {
                // The database deletion is authoritative. A missing/already
                // removed Firebase identity must not block the user's request.
            }
        }
    }
}
