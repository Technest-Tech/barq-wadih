<?php

namespace App\Http\Controllers\Api\V1;

use App\DTOs\RegisterData;
use App\DTOs\UpdateProfileData;
use App\Http\Requests\Auth\FirebaseAuthRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Services\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class AuthController extends BaseController
{
    public function __construct(private readonly AuthService $authService) {}

    // ── POST /api/v1/auth/register ────────────────────────────────────────────

    public function register(RegisterRequest $request): JsonResponse
    {
        $result = $this->authService->register(
            RegisterData::fromRequest($request->validated())
        );

        $user = $result['user']->load(['region', 'city']);

        return $this->successResponse(
            data: [
                'token' => $result['token'],
                'user'  => (new UserResource($user))->resolve(),
            ],
            message: 'تم إنشاء الحساب بنجاح.',
            code: 201
        );
    }

    // ── POST /api/v1/auth/login ───────────────────────────────────────────────

    public function login(LoginRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->loginWithPassword(
                email:    $request->validated('email'),
                password: $request->validated('password')
            );
        } catch (ValidationException $e) {
            return $this->errorResponse(
                message: $e->errors()['email'][0],
                code: 401
            );
        }

        $user = $result['user']->load(['region', 'city']);

        return $this->successResponse(
            data: [
                'token' => $result['token'],
                'user'  => (new UserResource($user))->resolve(),
            ],
            message: 'تم تسجيل الدخول بنجاح.'
        );
    }

    // ── POST /api/v1/auth/firebase ────────────────────────────────────────────

    public function firebase(FirebaseAuthRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->loginWithFirebaseToken(
                idToken: $request->validated('firebase_id_token'),
                name:    $request->validated('name'),
                locale:  $request->validated('locale') ?? 'ar',
            );
        } catch (ValidationException $e) {
            return $this->errorResponse(
                message: collect($e->errors())->flatten()->first(),
                code: 401
            );
        }

        $isNew = $result['user']->wasRecentlyCreated;
        $user  = $result['user']->load(['region', 'city']);

        return $this->successResponse(
            data: [
                'token'  => $result['token'],
                'user'   => (new UserResource($user))->resolve(),
                'is_new' => $isNew,
            ],
            message: $isNew ? 'تم إنشاء الحساب بنجاح.' : 'تم تسجيل الدخول بنجاح.',
            code: $isNew ? 201 : 200
        );
    }

    // ── POST /api/v1/auth/logout ──────────────────────────────────────────────

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->successResponse(message: 'تم تسجيل الخروج بنجاح.');
    }

    // ── POST /api/v1/auth/logout-all ─────────────────────────────────────────

    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return $this->successResponse(message: 'تم تسجيل الخروج من جميع الأجهزة.');
    }

    // ── GET /api/v1/auth/me ───────────────────────────────────────────────────

    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load(['region', 'city']);

        return $this->successResponse(
            data: (new UserResource($user))->resolve()
        );
    }

    // ── PUT /api/v1/auth/me ───────────────────────────────────────────────────

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $this->authService->updateProfile(
            user: $request->user(),
            data: UpdateProfileData::fromRequest($request->validated())
        );

        return $this->successResponse(
            data: (new UserResource($user))->resolve(),
            message: 'تم تحديث الملف الشخصي.'
        );
    }

    // ── POST /api/v1/auth/me/avatar ───────────────────────────────────────────

    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ]);

        $user = $this->authService->uploadAvatar(
            user: $request->user(),
            file: $request->file('avatar')
        );

        return $this->successResponse(
            data: ['avatar_url' => $user->avatar_url],
            message: 'تم تحديث الصورة الشخصية.'
        );
    }

    // ── POST /api/v1/auth/me/cover ────────────────────────────────────────────

    public function uploadCover(Request $request): JsonResponse
    {
        $request->validate([
            'cover' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192'],
        ]);

        $user = $this->authService->uploadCoverImage(
            user: $request->user(),
            file: $request->file('cover')
        );

        return $this->successResponse(
            data: ['cover_image_url' => $user->cover_image_url],
            message: 'تم تحديث صورة الغلاف.'
        );
    }
}
