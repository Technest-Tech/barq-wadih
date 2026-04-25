<?php

namespace App\Models;

use App\Enums\UserRole;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name', 'email', 'phone', 'password',
        'phone_verified_at', 'email_verified_at',
        'avatar', 'bio',
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
        'role'                   => UserRole::class,
        'email_verified_at'      => 'datetime',
        'phone_verified_at'      => 'datetime',
        'last_active_at'         => 'datetime',
        'password'               => 'hashed',
        'is_dealer'              => 'boolean',
        'is_verified'            => 'boolean',
        'is_active'              => 'boolean',
        'avg_rating'             => 'decimal:2',
        'total_ads_count'        => 'integer',
        'rating_count'           => 'integer',
        'commissions_paid_count' => 'integer',
        'commissions_due_count'  => 'integer',
    ];

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

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(UserSubscription::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** @param  \Illuminate\Database\Eloquent\Builder<User>  $query */
    public function scopeActive($query): void
    {
        $query->where('is_active', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<User>  $query */
    public function scopeVerified($query): void
    {
        $query->where('is_verified', true);
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<User>  $query */
    public function scopeDealers($query): void
    {
        $query->where('is_dealer', true)->active();
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<User>  $query */
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
            ->where('status', \App\Enums\SubscriptionStatus::Active->value)
            ->where('ends_at', '>', now())
            ->latest()
            ->first();
    }

    public function getUnreadNotificationsCountAttribute(): int
    {
        return Notification::where('user_id', $this->id)
            ->where('is_read', false)
            ->count();
    }
}
