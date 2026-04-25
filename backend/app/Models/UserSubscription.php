<?php

namespace App\Models;

use App\Enums\SubscriptionStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserSubscription extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'plan_id', 'status',
        'starts_at', 'ends_at', 'payment_id', 'auto_renew',
    ];

    protected $casts = [
        'status'     => SubscriptionStatus::class,
        'starts_at'  => 'datetime',
        'ends_at'    => 'datetime',
        'auto_renew' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'plan_id');
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<UserSubscription>  $query */
    public function scopeActive($query): void
    {
        $query->where('status', SubscriptionStatus::Active->value)
              ->where('ends_at', '>', now());
    }

    public function isExpired(): bool
    {
        return $this->ends_at->isPast();
    }
}
