<?php

namespace App\Services;

use App\DTOs\RegisterData;
use App\DTOs\UpdateProfileData;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function __construct(private readonly ImageService $imageService) {}
    // ── Registration ─────────────────────────────────────────────────────────

    public function register(RegisterData $data): array
    {
        $user = User::create([
            'name'      => $data->name,
            'phone'     => $data->phone,
            'email'     => $data->email,
            'password'  => $data->password ? Hash::make($data->password) : null,
            'region_id' => $data->regionId,
            'city_id'   => $data->cityId,
            'locale'    => $data->locale,
            'role'      => UserRole::User,
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
            $firebaseUid   = $verifiedToken->claims()->get('sub');
            $phone         = $verifiedToken->claims()->get('phone_number');
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
                'name'              => $name ?? 'مستخدم ' . Str::random(6),
                'phone'             => $phone,
                'firebase_uid'      => $firebaseUid,
                'phone_verified_at' => now(),
                'role'              => UserRole::User,
                'locale'            => $locale,
                'is_active'         => true,
            ]);
        } else {
            // Sync firebase_uid and mark phone as verified
            $user->update([
                'firebase_uid'      => $firebaseUid,
                'phone_verified_at' => $user->phone_verified_at ?? now(),
                'last_active_at'    => now(),
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
}
