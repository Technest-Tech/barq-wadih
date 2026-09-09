<?php

namespace App\Models;

use App\Enums\SubscriptionStatus;
use App\Enums\UserRole;
use App\Services\UsernameGenerator;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens;
    use HasFactory;
    use Notifiable;
    use SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name', 'email', 'phone', 'password',
        'phone_verified_at', 'email_verified_at',
        'avatar', 'cover_image', 'bio',
        'region_id', 'city_id',
        'is_dealer', 'is_verified', 'is_active',
        'role', 'firebase_uid', 'locale',
        'total_ads_count', 'avg_rating', 'rating_count',
        'commissions_paid_count', 'commissions_due_count',
        'last_active_at',
    ];

    /**
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'firebase_uid',
    ];

    /**
     * @var array<string, string>
     */
    protected $casts = [
        'role' => UserRole::class,
        'email_verified_at' => 'datetime',
        'phone_verified_at' => 'datetime',
        'last_active_at' => 'datetime',
        'password' => 'hashed',
        'is_dealer' => 'boolean',
        'is_verified' => 'boolean',
        'is_active' => 'boolean',
        'avg_rating' => 'decimal:2',
        'total_ads_count' => 'integer',
        'rating_count' => 'integer',
        'commissions_paid_count' => 'integer',
        'commissions_due_count' => 'integer',
    ];

    // ── Model events ─────────────────────────────────────────────────────────

    protected static function booted(): void
    {
        // Assign the public @handle after insert, when the id (used to break
        // ties between users with the same display name) is known.
        static::created(function (User $user): void {
            if (blank($user->username)) {
                $user->assignUsername();
            }
        });
    }

    /**
     * Claim a public @handle, retrying on the unique index instead of failing
     * the signup: two people registering under the same name in the same
     * moment can both settle on a candidate before either row lands.
     */
    public function assignUsername(): void
    {
        foreach (UsernameGenerator::candidates($this->name, $this->id) as $candidate) {
            if (UsernameGenerator::isTaken($candidate)) {
                continue;
            }

            try {
                $this->username = $candidate;
                $this->saveQuietly();

                return;
            } catch (UniqueConstraintViolationException) {
                // Lost the race — fall through and try the next candidate.
            }
        }

        // Every candidate was taken. Leave the row handle-less rather than
        // reporting one that was never stored; profile_url falls back to null
        // and the id route still resolves.
        $this->username = null;
    }

    // ── Route binding ────────────────────────────────────────────────────────

    /**
     * Resolve `{user}` from either a numeric id (/users/12) or a public handle
     * (/users/@ahmd_aamr), so shareable links work against the same routes.
     */
    public function resolveRouteBinding($value, $field = null): ?Model
    {
        if ($field === null && is_string($value) && str_starts_with($value, '@')) {
            // Handles are generated lowercase; normalising here keeps the
            // lookup case-insensitive on SQLite too, matching what the website
            // does before it hands the handle over.
            $handle = mb_strtolower(substr($value, 1));

            return $handle === '' ? null : $this->where('username', $handle)->first();
        }

        // Anything but a plain integer on the id route is a bad link, not a
        // lookup — returning null 404s instead of letting the DB type-juggle
        // "12.5" or "12abc" into a row.
        if ($field === null && ! ctype_digit((string) $value)) {
            return null;
        }

        return parent::resolveRouteBinding($value, $field);
    }

    // ── Relationships ────────────────────────────────────────────────────────

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class);
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }

    public function ads(): HasMany
    {
        return $this->hasMany(Ad::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(UserDevice::class);
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(Favorite::class);
    }

    public function ratingsGiven(): HasMany
    {
        return $this->hasMany(Rating::class, 'rater_id');
    }

    public function ratingsReceived(): HasMany
    {
        return $this->hasMany(Rating::class, 'rated_user_id');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(Report::class, 'reporter_id');
    }

    public function commissionPayments(): HasMany
    {
        return $this->hasMany(CommissionPayment::class);
    }

    public function categoryFollows(): HasMany
    {
        return $this->hasMany(CategoryFollow::class);
    }

    /** Sellers this user follows. */
    public function sellerFollows(): HasMany
    {
        return $this->hasMany(UserFollow::class, 'follower_id');
    }

    /** Users following this user (i.e. this user is the seller). */
    public function followers(): HasMany
    {
        return $this->hasMany(UserFollow::class, 'followed_id');
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(UserSubscription::class);
    }

    /** Users this account has blocked. */
    public function blockedUsers(): BelongsToMany
    {
        return $this->belongsToMany(
            User::class,
            'user_blocks',
            'blocker_id',
            'blocked_id',
        )->withTimestamps();
    }

    /** Users that have blocked this account. */
    public function blockedByUsers(): BelongsToMany
    {
        return $this->belongsToMany(
            User::class,
            'user_blocks',
            'blocked_id',
            'blocker_id',
        )->withTimestamps();
    }

    public function hasBlocked(User|int $user): bool
    {
        $userId = $user instanceof User ? $user->id : $user;

        return $this->blockedUsers()->whereKey($userId)->exists();
    }

    public function cannotInteractWith(User|int $user): bool
    {
        $userId = $user instanceof User ? $user->id : $user;

        return UserBlock::query()
            ->where(function ($query) use ($userId) {
                $query->where('blocker_id', $this->id)
                    ->where('blocked_id', $userId);
            })
            ->orWhere(function ($query) use ($userId) {
                $query->where('blocker_id', $userId)
                    ->where('blocked_id', $this->id);
            })
            ->exists();
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  Builder<User>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  Builder<User>  $query */
    public function scopeVerified($query): void
    {
        $query->where('is_verified', true);
    }

    /** @param  Builder<User>  $query */
    public function scopeDealers($query): void
    {
        $query->where('is_dealer', true)->active();
    }

    /** @param  Builder<User>  $query */
    public function scopeAdmins($query): void
    {
        $query->whereIn('role', [UserRole::Admin->value, UserRole::SuperAdmin->value]);
    }

    // ── Accessors / Helpers ──────────────────────────────────────────────────

    public function isAdmin(): bool
    {
        return in_array($this->role, [UserRole::Admin, UserRole::SuperAdmin], strict: true);
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === UserRole::SuperAdmin;
    }

    public function hasVerifiedPhone(): bool
    {
        return $this->phone_verified_at !== null;
    }

    public function getActiveSubscription(): ?UserSubscription
    {
        return UserSubscription::where('user_id', $this->id)
            ->where('status', SubscriptionStatus::Active->value)
            ->where('ends_at', '>', now())
            ->latest()
            ->first();
    }

    public function getAvatarUrlAttribute(): ?string
    {
        if (! $this->avatar) {
            return null;
        }
        if (str_starts_with($this->avatar, 'http')) {
            return $this->avatar;
        }
        // Legacy relative path — resolve via active disk.
        $disk = config('filesystems.default', 'local') === 'local' ? 'public' : config('filesystems.default');

        return Storage::disk($disk)->url($this->avatar);
    }

    public function getCoverImageUrlAttribute(): ?string
    {
        if (! $this->cover_image) {
            return null;
        }
        if (str_starts_with($this->cover_image, 'http')) {
            return $this->cover_image;
        }
        // Legacy relative path — resolve via active disk.
        $disk = config('filesystems.default', 'local') === 'local' ? 'public' : config('filesystems.default');

        return Storage::disk($disk)->url($this->cover_image);
    }

    /**
     * Shareable public profile link — mirrors the Next.js /@{handle} route.
     * Null for the handful of rows a failed backfill could leave without one.
     */
    public function getProfileUrlAttribute(): ?string
    {
        return $this->username
            ? config('app.frontend_url').'/@'.$this->username
            : null;
    }

    public function getUnreadNotificationsCountAttribute(): int
    {
        return Notification::where('user_id', $this->id)
            ->where('is_read', false)
            ->count();
    }
}
